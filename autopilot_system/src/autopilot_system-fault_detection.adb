with Ada.Assertions;                use Ada.Assertions;
with Ada.Exceptions;                use Ada.Exceptions;
with Ada.Real_Time;                 use Ada.Real_Time;
with Autopilot_System.Types;        use Autopilot_System.Types;
with Autopilot_System.Vehicle_State;

package body Autopilot_System.Fault_Detection is

   Timeout_Limit : constant Time_Span := To_Time_Span (SENSOR_TIMEOUT);

   function Timed_Out (Last_Update : Sensor_Time) return Boolean is
     (Clock - Last_Update > Timeout_Limit);

   function Timeout_Count return Natural is
     (Boolean'Pos
        (Timed_Out (Autopilot_System.Vehicle_State.Shared.Get_Last_Speed_Update))
      + Boolean'Pos
        (Timed_Out
           (Autopilot_System.Vehicle_State.Shared.Get_Last_Distance_Update))
      + Boolean'Pos
        (Timed_Out (Autopilot_System.Vehicle_State.Shared.Get_Last_Lane_Update)));

   procedure Log_Exception
     (Context : in String;
      E       : in Exception_Occurrence) is
   begin
      Log ("FAULT_DET",
           Context & ": " & Exception_Name (E) & " " & Exception_Message (E));
   end Log_Exception;

   procedure Apply_State_If_Allowed (Target : in System_State) is
      Current : constant System_State :=
        Autopilot_System.Vehicle_State.Shared.Get_State;
   begin
      if Current /= Target and then Is_Valid_Transition (Current, Target) then
         Autopilot_System.Vehicle_State.Shared.Set_State (Target);
      end if;
   exception
      when E : Assertion_Error | Invalid_Transition =>
         Log_Exception ("State transition rejected", E);
      when E : others =>
         Log_Exception ("State transition failure", E);
   end Apply_State_If_Allowed;

   procedure Set_Fault_And_State
     (Fault   : in Fault_Level;
      Target  : in System_State;
      Message : in String) is
   begin
      Autopilot_System.Vehicle_State.Shared.Set_Fault (Fault);
      Apply_State_If_Allowed (Target);
      Log ("FAULT_DET", Message);
   exception
      when E : Assertion_Error | Constraint_Error =>
         Log_Exception ("Fault/state contract failure", E);
      when E : others =>
         Log_Exception ("Fault/state runtime failure", E);
   end Set_Fault_And_State;

   procedure Apply_Minor_Warning
     (Current : in System_State;
      Message : in String) is
   begin
      Autopilot_System.Vehicle_State.Shared.Set_Fault (WARNING);

      if Current = ACTIVE then
         Apply_State_If_Allowed (FAULT_MINOR);
      end if;

      Log ("FAULT_DET", Message);
   exception
      when E : Assertion_Error | Constraint_Error =>
         Log_Exception ("Minor warning contract failure", E);
      when E : others =>
         Log_Exception ("Minor warning runtime failure", E);
   end Apply_Minor_Warning;

   procedure Clear_Operational_Faults (Current : in System_State) is
   begin
      if Current = FAULT_MINOR then
         Autopilot_System.Vehicle_State.Shared.Set_Fault (NONE);
         Apply_State_If_Allowed (ACTIVE);
         Log ("FAULT_DET", "Fault cleared -> ACTIVE");
      elsif Current = ACTIVE
        and then Autopilot_System.Vehicle_State.Shared.Get_Fault /= NONE
      then
         Autopilot_System.Vehicle_State.Shared.Set_Fault (NONE);
      end if;
   exception
      when E : Assertion_Error | Constraint_Error =>
         Log_Exception ("Fault clear contract failure", E);
      when E : others =>
         Log_Exception ("Fault clear runtime failure", E);
   end Clear_Operational_Faults;

   procedure Handle_Engaging_State
     (Sensors : in Sensor_Data;
      Timeouts : in Natural) is
   begin
      if All_Sensors_Valid (Sensors) and then Timeouts = 0 then
         Autopilot_System.Vehicle_State.Shared.Set_Fault (NONE);
         Apply_State_If_Allowed (ACTIVE);
         Log ("FAULT_DET", "Sensors OK -> activating autopilot");
      else
         Set_Fault_And_State
           (CRITICAL,
            FAULT_MAJOR,
            "Engagement blocked by invalid or timed-out sensors");
      end if;
   end Handle_Engaging_State;

   procedure Handle_Emergency_State
     (Sensors  : in Sensor_Data;
      Timeouts : in Natural) is
   begin
      if Multiple_Sensors_Failed (Sensors) then
         Set_Fault_And_State
           (FATAL,
            SAFE_STOP,
            "Multiple sensor failures during emergency -> SAFE_STOP");
      elsif Timeouts > 0 then
         Set_Fault_And_State
           (FATAL,
            SAFE_STOP,
            "Sensor timeout during emergency -> SAFE_STOP");
      elsif Sensors.Speed_Valid and then Sensors.Speed < 1.0 then
         Set_Fault_And_State (CRITICAL, SAFE_STOP, "Vehicle stopped -> SAFE_STOP");
      end if;
   end Handle_Emergency_State;

   procedure Classify_Operational_Faults
     (Current  : in System_State;
      Sensors  : in Sensor_Data;
      Timeouts : in Natural) is
   begin
      if Multiple_Sensors_Failed (Sensors) then
         Set_Fault_And_State
           (FATAL,
            SAFE_STOP,
            "Multiple sensors failed simultaneously -> SAFE_STOP");
      elsif Timeouts > 0 then
         Set_Fault_And_State
           (CRITICAL,
            FAULT_MAJOR,
            "Sensor timeout -> FAULT_MAJOR");
      elsif Any_Sensor_Invalid (Sensors) then
         Set_Fault_And_State
           (CRITICAL,
            FAULT_MAJOR,
            "Invalid sensor data -> FAULT_MAJOR");
      elsif Sensors.Distance_Valid
        and then Sensors.Front_Distance < MIN_SAFE_DISTANCE
      then
         Set_Fault_And_State
           (CRITICAL,
            EMERGENCY,
            "Collision danger! Dist=" &
            Float'Image (Sensors.Front_Distance) & " m");
      elsif Sensors.Speed_Valid and then Sensors.Speed > MAX_SPEED then
         Apply_Minor_Warning
           (Current,
            "Overspeed: " & Float'Image (Sensors.Speed) & " km/h");
      elsif Sensors.Lane_Valid and then abs (Sensors.Lane_Offset) > MAX_LANE_OFFSET then
         Apply_Minor_Warning
           (Current,
            "Lane deviation: " & Float'Image (Sensors.Lane_Offset) & " m");
      else
         Clear_Operational_Faults (Current);
      end if;
   end Classify_Operational_Faults;

   procedure Handle_Runtime_Failure
     (Current : in System_State;
      E       : in Exception_Occurrence) is
   begin
      Log_Exception ("Monitoring cycle failure", E);

      begin
         Autopilot_System.Vehicle_State.Shared.Set_Fault (FATAL);
      exception
         when others =>
            null;
      end;

      begin
         if Current /= STANDBY
           and then Current /= SAFE_STOP
           and then Is_Valid_Transition (Current, SAFE_STOP)
         then
            Autopilot_System.Vehicle_State.Shared.Set_State (SAFE_STOP);
         end if;
      exception
         when others =>
            null;
      end;
   end Handle_Runtime_Failure;

   procedure Log_State_Changes
     (Prev_State : in out System_State;
      Prev_Fault : in out Fault_Level) is
      New_State : constant System_State :=
        Autopilot_System.Vehicle_State.Shared.Get_State;
      New_Fault : constant Fault_Level :=
        Autopilot_System.Vehicle_State.Shared.Get_Fault;
   begin
      if New_State /= Prev_State then
         Log ("STATE",
              System_State'Image (Prev_State) & " -> " &
              System_State'Image (New_State));
         Prev_State := New_State;
      end if;

      if New_Fault /= Prev_Fault then
         Log ("FAULT",
              Fault_Level'Image (Prev_Fault) & " -> " &
              Fault_Level'Image (New_Fault));
         Prev_Fault := New_Fault;
      end if;
   end Log_State_Changes;

   task body Fault_Detection_Task is
      Sensors    : Sensor_Data;
      Current    : System_State := STANDBY;
      Prev_State : System_State := STANDBY;
      Prev_Fault : Fault_Level := NONE;
      Timeouts   : Natural := 0;
   begin
      accept Start;
      Log ("FAULT_DET", "Task started");

      loop
         select
            accept Stop;
            Log ("FAULT_DET", "Task stopping");
            exit;
         or
            delay 0.1;
         end select;

         begin
            Sensors  := Autopilot_System.Vehicle_State.Shared.Get_Sensors;
            Current  := Autopilot_System.Vehicle_State.Shared.Get_State;
            Timeouts := Timeout_Count;

            if Current in STANDBY | SAFE_STOP then
               null;
            elsif Current = ENGAGING then
               Handle_Engaging_State (Sensors, Timeouts);
            elsif Current = EMERGENCY then
               Handle_Emergency_State (Sensors, Timeouts);
            else
               Classify_Operational_Faults (Current, Sensors, Timeouts);
            end if;
         exception
            when E : Assertion_Error | Constraint_Error =>
               Handle_Runtime_Failure (Current, E);
            when E : others =>
               Handle_Runtime_Failure (Current, E);
         end;

         Log_State_Changes (Prev_State, Prev_Fault);
      end loop;
   end Fault_Detection_Task;

end Autopilot_System.Fault_Detection;
