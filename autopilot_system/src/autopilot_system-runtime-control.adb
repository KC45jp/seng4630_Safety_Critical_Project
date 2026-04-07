with Ada.Assertions;                use Ada.Assertions;
with Ada.Exceptions;                use Ada.Exceptions;
with Autopilot_System.Domain.Types;        use Autopilot_System.Domain.Types;
with Autopilot_System.Runtime.State;

package body Autopilot_System.Runtime.Control is

   function Clamp (Value, Lo, Hi : Float) return Float is
     (Float'Max (Lo, Float'Min (Hi, Value)));

   function Idle_Output return Actuator_Output is
     (Throttle => 0.0,
      Brake    => 0.0,
      Steering => 0.0);

   function Degraded_Output return Actuator_Output is
     (Throttle => 0.0,
      Brake    => 0.3,
      Steering => 0.0);

   function Emergency_Output return Actuator_Output is
     (Throttle => 0.0,
      Brake    => 1.0,
      Steering => 0.0);

   function Nominal_Output (Sensors : Sensor_Data) return Actuator_Output is
      Output    : Actuator_Output := Idle_Output;
      Speed_Err : constant Float := TARGET_SPEED - Sensors.Speed;
      Dist_Err  : Float;
   begin
      Output.Throttle := Clamp (Speed_Err / 50.0, 0.0, 1.0);
      Output.Steering := Clamp (-Sensors.Lane_Offset * 2.0, -1.0, 1.0);

      if Sensors.Speed_Valid and then Sensors.Speed > MAX_SPEED then
         Output.Throttle := 0.0;
      end if;

      if Sensors.Distance_Valid and then Sensors.Front_Distance < SAFE_FOLLOW_DIST then
         Dist_Err        := SAFE_FOLLOW_DIST - Sensors.Front_Distance;
         Output.Brake    := Clamp (Dist_Err / 20.0, 0.0, 1.0);
         Output.Throttle := 0.0;
      end if;

      return Output;
   end Nominal_Output;

   function Select_Output
     (Current : System_State;
      Sensors : Sensor_Data) return Actuator_Output is
   begin
      case Current is
         when STANDBY | ENGAGING =>
            return Idle_Output;

         when ACTIVE | WARNING_ACTIVE =>
            if All_Sensors_Valid (Sensors) then
               return Nominal_Output (Sensors);
            else
               return Degraded_Output;
            end if;

         when SENSOR_FAULT =>
            return Degraded_Output;

         when EMERGENCY | SAFE_STOP =>
            return Emergency_Output;
      end case;
   end Select_Output;

   procedure Log_Control_Output
     (Current    : in System_State;
      Output     : in Actuator_Output;
      Step       : in Natural;
      Prev_State : in out System_State) is
   begin
      if Current /= Prev_State or else Step mod 10 = 0 then
         Log ("CONTROL",
              System_State'Image (Current) &
              " Thr=" & Float'Image (Output.Throttle) &
              " Brk=" & Float'Image (Output.Brake) &
              " Str=" & Float'Image (Output.Steering));
         Prev_State := Current;
      end if;
   end Log_Control_Output;

   procedure Handle_Control_Failure
     (Current : in System_State;
      E       : in Exception_Occurrence) is
   begin
      Log ("CONTROL",
           "Control cycle failure: " & Exception_Name (E) &
           " " & Exception_Message (E));

      begin
         Autopilot_System.Runtime.State.Shared.Set_Actuators (Emergency_Output);
      exception
         when others =>
            null;
      end;

      begin
         Autopilot_System.Runtime.State.Shared.Set_Fault (FATAL);
      exception
         when others =>
            null;
      end;

      begin
         if Current /= STANDBY
           and then Current /= SAFE_STOP
           and then Is_Valid_Transition (Current, SAFE_STOP)
         then
            Autopilot_System.Runtime.State.Shared.Set_State (SAFE_STOP);
         end if;
      exception
         when others =>
            null;
      end;
   end Handle_Control_Failure;

   procedure Apply_Immediate_Output (Mode : in Immediate_Output_Mode) is
      Output : constant Actuator_Output :=
        (case Mode is
            when IDLE_NOW => Idle_Output,
            when EMERGENCY_NOW => Emergency_Output);
      Current : constant Actuator_Output :=
        Autopilot_System.Runtime.State.Shared.Get_Actuators;
   begin
      if Current = Output then
         return;
      end if;

      Autopilot_System.Runtime.State.Shared.Set_Actuators (Output);
      Log ("CONTROL",
           "Immediate output applied: " & Immediate_Output_Mode'Image (Mode));
   exception
      when E : Assertion_Error | Constraint_Error =>
         Log ("CONTROL",
              "Immediate output contract failure: " & Exception_Name (E) &
              " " & Exception_Message (E));
      when E : others =>
         Log ("CONTROL",
              "Immediate output failure: " & Exception_Name (E) &
              " " & Exception_Message (E));
   end Apply_Immediate_Output;

   task body Control_Task is
      Sensors    : Sensor_Data;
      Current    : System_State := STANDBY;
      Output     : Actuator_Output := Idle_Output;
      Step       : Natural := 0;
      Prev_State : System_State := STANDBY;
   begin
      accept Start;
      Log ("CONTROL", "Task started");

      loop
         select
            accept Stop;
            Log ("CONTROL", "Task stopping");
            exit;
         or
            delay 0.1;
         end select;

         begin
            Sensors := Autopilot_System.Runtime.State.Shared.Get_Sensors;
            Current := Autopilot_System.Runtime.State.Shared.Get_State;
            Step    := Step + 1;
            Output  := Select_Output (Current, Sensors);
            Autopilot_System.Runtime.State.Shared.Set_Actuators (Output);
         exception
            when E : Assertion_Error | Constraint_Error =>
               Handle_Control_Failure (Current, E);
               Output := Emergency_Output;
            when E : others =>
               Handle_Control_Failure (Current, E);
               Output := Emergency_Output;
         end;

         Log_Control_Output (Current, Output, Step, Prev_State);
      end loop;
   end Control_Task;

end Autopilot_System.Runtime.Control;
