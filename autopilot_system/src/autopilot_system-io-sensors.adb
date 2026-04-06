with Ada.Assertions;                use Ada.Assertions;
with Ada.Characters.Handling;       use Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Exceptions;                use Ada.Exceptions;
with Ada.Strings;                   use Ada.Strings;
with Ada.Strings.Fixed;             use Ada.Strings.Fixed;
with Ada.Text_IO;                   use Ada.Text_IO;
with Autopilot_System.IO.Driver_Input;
with Autopilot_System.Domain.Types;        use Autopilot_System.Domain.Types;
with Autopilot_System.Runtime.State;

package body Autopilot_System.IO.Sensors is

   Trace_Header : constant String :=
     "step,observed_state,observed_fault,observed_speed,observed_distance," &
     "observed_lane,observed_speed_valid,observed_distance_valid," &
     "observed_lane_valid,observed_throttle,observed_brake," &
     "observed_steering";

   type Scenario_Command is
     (COMMAND_NONE,
      COMMAND_ENGAGE,
      COMMAND_DISENGAGE,
      COMMAND_OVERRIDE);

   type Actuator_Mode is
     (IDLE_OUTPUT,
      NOMINAL_OUTPUT,
      DEGRADED_OUTPUT,
      EMERGENCY_OUTPUT);

   type Optional_Float is record
      Present : Boolean := False;
      Value   : Float := 0.0;
   end record;

   type Scenario_Row is record
      Step           : Positive;
      Speed_Value    : Optional_Float;
      Distance_Value : Optional_Float;
      Lane_Value     : Optional_Float;
      Command                : Scenario_Command := COMMAND_NONE;
      Expected_State         : System_State := STANDBY;
      Expected_Fault         : Fault_Level := NONE;
      Expected_Actuator_Mode : Actuator_Mode := IDLE_OUTPUT;
   end record;

   function Empty_Frame return Sensor_Data is
     (Speed          => 0.0,
      Front_Distance => 0.0,
      Lane_Offset    => 0.0,
      Speed_Valid    => False,
      Distance_Valid => False,
      Lane_Valid     => False);

   function Trimmed (Value : String) return String is
      Sanitized : constant String :=
        (if Value'Length > 0 and then Value (Value'Last) = Ada.Characters.Latin_1.CR
         then Value (Value'First .. Value'Last - 1)
         else Value);
   begin
      return Trim (Sanitized, Both);
   end Trimmed;

   function Normalized (Value : String) return String is
     (To_Upper (Trimmed (Value)));

   function Boolean_Text (Value : Boolean) return String is
     (if Value then "TRUE" else "FALSE");

   function Float_Text (Value : Float) return String is
     (Trim (Float'Image (Value), Both));

   function Field_Count (Line : String) return Natural is
      Count : Natural := 1;
   begin
      if Line'Length = 0 then
         return 0;
      end if;

      for Index in Line'Range loop
         if Line (Index) = ',' then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Field_Count;

   function Field_At (Line : String; Number : Positive) return String is
      Current_Field : Positive := 1;
      Start_Index   : Positive := Line'First;
   begin
      if Line'Length = 0 then
         return "";
      end if;

      for Index in Line'Range loop
         if Line (Index) = ',' then
            if Current_Field = Number then
               if Start_Index > Index - 1 then
                  return "";
               end if;
               return Line (Start_Index .. Index - 1);
            end if;

            Current_Field := Current_Field + 1;
            Start_Index   := Index + 1;
         end if;
      end loop;

      if Current_Field = Number then
         if Start_Index > Line'Last then
            return "";
         end if;
         return Line (Start_Index .. Line'Last);
      end if;

      return "";
   end Field_At;

   function Parse_Command (Value : String) return Scenario_Command is
      Token : constant String := Normalized (Value);
   begin
      if Token = "NONE" then
         return COMMAND_NONE;
      elsif Token = "ENGAGE" then
         return COMMAND_ENGAGE;
      elsif Token = "DISENGAGE" then
         return COMMAND_DISENGAGE;
      elsif Token = "OVERRIDE" then
         return COMMAND_OVERRIDE;
      end if;

      raise Constraint_Error with "Invalid driver command: " & Value;
   end Parse_Command;

   function Parse_Actuator_Mode (Value : String) return Actuator_Mode is
      Token : constant String := Normalized (Value);
   begin
      if Token = "IDLE_OUTPUT" then
         return IDLE_OUTPUT;
      elsif Token = "NOMINAL_OUTPUT" then
         return NOMINAL_OUTPUT;
      elsif Token = "DEGRADED_OUTPUT" then
         return DEGRADED_OUTPUT;
      elsif Token = "EMERGENCY_OUTPUT" then
         return EMERGENCY_OUTPUT;
      end if;

      raise Constraint_Error with "Invalid actuator mode: " & Value;
   end Parse_Actuator_Mode;

   function Parse_Optional_Float (Value : String) return Optional_Float is
      Token : constant String := Trimmed (Value);
   begin
      if Token = "" then
         return (Present => False, Value => 0.0);
      end if;

      return (Present => True, Value => Float'Value (Token));
   end Parse_Optional_Float;

   function Speed_Is_Plausible (Value : Float) return Boolean is
     (Value >= 0.0 and then Value <= MAX_PLAUSIBLE_SPEED);

   function Distance_Is_Plausible (Value : Float) return Boolean is
     (Value >= 0.0 and then Value <= MAX_PLAUSIBLE_DISTANCE);

   function Lane_Is_Plausible (Value : Float) return Boolean is
     (abs (Value) <= MAX_PLAUSIBLE_LANE_OFFSET);

   function Header_Matches (Line : String) return Boolean is
   begin
      return Field_Count (Line) = 10
        and then Normalized (Field_At (Line, 1)) = "STEP"
        and then Normalized (Field_At (Line, 2)) = "SPEED_VALUE"
        and then Normalized (Field_At (Line, 3)) = "DISTANCE_VALUE"
        and then Normalized (Field_At (Line, 4)) = "LANE_VALUE"
        and then Normalized (Field_At (Line, 5)) = "DRIVER_COMMAND"
        and then Normalized (Field_At (Line, 6)) = "EXPECTED_STATE"
        and then Normalized (Field_At (Line, 7)) = "EXPECTED_FAULT"
        and then Normalized (Field_At (Line, 8)) = "EXPECTED_ACTUATOR_MODE"
        and then Normalized (Field_At (Line, 9)) = "TRANSITION_LOOKBACK_TICKS"
        and then Normalized (Field_At (Line, 10)) = "NOTE";
   end Header_Matches;

   function Parse_Row (Line : String) return Scenario_Row is
      Row : Scenario_Row;
   begin
      if Field_Count (Line) /= 10 then
         raise Constraint_Error with "Scenario row must have 10 fields";
      end if;

      Row.Step           := Positive'Value (Trimmed (Field_At (Line, 1)));
      Row.Speed_Value    := Parse_Optional_Float (Field_At (Line, 2));
      Row.Distance_Value := Parse_Optional_Float (Field_At (Line, 3));
      Row.Lane_Value     := Parse_Optional_Float (Field_At (Line, 4));
      Row.Command                := Parse_Command (Field_At (Line, 5));
      Row.Expected_State         :=
        System_State'Value (Normalized (Field_At (Line, 6)));
      Row.Expected_Fault         :=
        Fault_Level'Value (Normalized (Field_At (Line, 7)));
      Row.Expected_Actuator_Mode := Parse_Actuator_Mode (Field_At (Line, 8));
      declare
         Unused_Lookback : constant Natural :=
           Natural'Value (Trimmed (Field_At (Line, 9)));
      begin
         null;
      end;

      return Row;
   end Parse_Row;

   procedure Log_Cycle_Exception
     (Context : in String;
      E       : in Exception_Occurrence) is
   begin
      Log ("SENSOR",
           Context & ": " & Exception_Name (E) & " " & Exception_Message (E));
   end Log_Cycle_Exception;

   procedure Log_Sensor_Snapshot (Step : in Natural; Data : in Sensor_Data) is
   begin
      if Step mod 20 /= 0 then
         return;
      end if;

      if All_Sensors_Valid (Data) then
         Log ("SENSOR",
              "Step" & Natural'Image (Step) &
              " Spd=" & Float_Text (Data.Speed) &
              " Dist=" & Float_Text (Data.Front_Distance) &
              " Lane=" & Float_Text (Data.Lane_Offset));
      else
         Log ("SENSOR",
              "Step" & Natural'Image (Step) &
              " Validity S=" & Boolean_Text (Data.Speed_Valid) &
              " D=" & Boolean_Text (Data.Distance_Valid) &
              " L=" & Boolean_Text (Data.Lane_Valid));
      end if;
   end Log_Sensor_Snapshot;

   procedure Write_Trace_Row
     (Trace_File : in out File_Type;
      Enabled    : in Boolean;
      Step       : in Positive;
      Data       : in Sensor_Data) is
      State : constant System_State :=
        Autopilot_System.Runtime.State.Shared.Get_State;
      Fault : constant Fault_Level :=
        Autopilot_System.Runtime.State.Shared.Get_Fault;
      Actuators : constant Actuator_Output :=
        Autopilot_System.Runtime.State.Shared.Get_Actuators;
   begin
      if not Enabled then
         return;
      end if;

      Put_Line
        (Trace_File,
         Trim (Positive'Image (Step), Both) & "," &
         Trim (System_State'Image (State), Both) & "," &
         Trim (Fault_Level'Image (Fault), Both) & "," &
         Float_Text (Data.Speed) & "," &
         Float_Text (Data.Front_Distance) & "," &
         Float_Text (Data.Lane_Offset) & "," &
         Boolean_Text (Data.Speed_Valid) & "," &
         Boolean_Text (Data.Distance_Valid) & "," &
         Boolean_Text (Data.Lane_Valid) & "," &
         Float_Text (Actuators.Throttle) & "," &
         Float_Text (Actuators.Brake) & "," &
         Float_Text (Actuators.Steering));
   end Write_Trace_Row;

   function To_Driver_Command (Command : Scenario_Command) return Driver_Command is
   begin
      case Command is
         when COMMAND_ENGAGE =>
            return ENGAGE;
         when COMMAND_DISENGAGE =>
            return DISENGAGE;
         when COMMAND_OVERRIDE =>
            return OVERRIDE;
         when COMMAND_NONE =>
            raise Constraint_Error with "No driver command to convert";
      end case;
   end To_Driver_Command;

   procedure Apply_Speed
     (Row  : in Scenario_Row;
      Data : in out Sensor_Data) is
   begin
      if not Row.Speed_Value.Present then
         return;
      end if;

      declare
         Value : constant Float := Row.Speed_Value.Value;
      begin
         Data.Speed       := Value;
         Data.Speed_Valid := Speed_Is_Plausible (Value);
         Autopilot_System.Runtime.State.Shared.Update_Speed
           (Value, Data.Speed_Valid);
      end;
   end Apply_Speed;

   procedure Apply_Distance
     (Row  : in Scenario_Row;
      Data : in out Sensor_Data) is
   begin
      if not Row.Distance_Value.Present then
         return;
      end if;

      declare
         Value : constant Float := Row.Distance_Value.Value;
      begin
         Data.Front_Distance := Value;
         Data.Distance_Valid := Distance_Is_Plausible (Value);
         Autopilot_System.Runtime.State.Shared.Update_Distance
           (Value, Data.Distance_Valid);
      end;
   end Apply_Distance;

   procedure Apply_Lane
     (Row  : in Scenario_Row;
      Data : in out Sensor_Data) is
   begin
      if not Row.Lane_Value.Present then
         return;
      end if;

      declare
         Value : constant Float := Row.Lane_Value.Value;
      begin
         Data.Lane_Offset := Value;
         Data.Lane_Valid  := Lane_Is_Plausible (Value);
         Autopilot_System.Runtime.State.Shared.Update_Lane
           (Value, Data.Lane_Valid);
      end;
   end Apply_Lane;

   procedure Apply_Row
     (Row  : in Scenario_Row;
      Data : in out Sensor_Data) is
   begin
      if Row.Command /= COMMAND_NONE then
         Autopilot_System.IO.Driver_Input.Apply_Command (To_Driver_Command (Row.Command));
      end if;

      Apply_Speed (Row, Data);
      Apply_Distance (Row, Data);
      Apply_Lane (Row, Data);
   end Apply_Row;

   task body Sensor_Task is
      Scenario_File  : File_Type;
      Trace_File     : File_Type;
      Trace_Enabled  : Boolean := False;
      Replay_Ready   : Boolean := False;
      Data           : Sensor_Data := Empty_Frame;
      Line_Buffer    : String (1 .. 512);
      Last           : Natural := 0;
      Next_Row       : Scenario_Row;
      Expected_Step  : Positive := 1;
   begin
      accept Start;
      Log ("SENSOR", "Task started");

      declare
         Scenario_File_Path : constant String := Autopilot_System.Scenario_Path;
         Trace_File_Path    : constant String := Autopilot_System.Trace_Path;
      begin
         if Scenario_File_Path = "" then
            raise Constraint_Error with "Scenario path is required";
         end if;

         Open (Scenario_File, In_File, Scenario_File_Path);
         if End_Of_File (Scenario_File) then
            raise Constraint_Error with "Scenario file is empty";
         end if;

         Get_Line (Scenario_File, Line_Buffer, Last);
         if not Header_Matches (Line_Buffer (1 .. Last)) then
            raise Constraint_Error with "Scenario header does not match expected schema";
         end if;

         if Trace_File_Path /= "" then
            Create (Trace_File, Out_File, Trace_File_Path);
            Put_Line (Trace_File, Trace_Header);
            Trace_Enabled := True;
         end if;

         Data         := Autopilot_System.Runtime.State.Shared.Get_Sensors;
         Replay_Ready := True;
         Log ("SENSOR", "Loaded scenario: " & Scenario_File_Path);
      exception
         when E : others =>
            Log_Cycle_Exception ("Scenario setup failure", E);
            Autopilot_System.Mark_Run_Failed;
            Autopilot_System.Mark_Scenario_Complete;
      end;

      if Replay_Ready then
         loop
            select
               accept Stop;
               Log ("SENSOR", "Task stopping");
               exit;
            or
               delay 0.05;
            end select;

            if End_Of_File (Scenario_File) then
               Log ("SENSOR", "Scenario reached EOF");
               Autopilot_System.Mark_Scenario_Complete;
               exit;
            end if;

            begin
               Get_Line (Scenario_File, Line_Buffer, Last);
               Next_Row := Parse_Row (Line_Buffer (1 .. Last));

               if Next_Row.Step /= Expected_Step then
                  raise Constraint_Error with
                    "Unexpected step" & Positive'Image (Next_Row.Step) &
                    ", expected" & Positive'Image (Expected_Step);
               end if;

               Apply_Row (Next_Row, Data);
               Data := Autopilot_System.Runtime.State.Shared.Get_Sensors;
               Write_Trace_Row (Trace_File, Trace_Enabled, Next_Row.Step, Data);
               Log_Sensor_Snapshot (Next_Row.Step, Data);
               Expected_Step := Expected_Step + 1;
            exception
               when E : Assertion_Error | Constraint_Error =>
                  Log_Cycle_Exception ("Scenario contract failure", E);
                  Autopilot_System.Mark_Run_Failed;
                  Autopilot_System.Mark_Scenario_Complete;
                  exit;
               when E : others =>
                  Log_Cycle_Exception ("Scenario runtime failure", E);
                  Autopilot_System.Mark_Run_Failed;
                  Autopilot_System.Mark_Scenario_Complete;
                  exit;
            end;
         end loop;
      end if;

      accept Stop;
      Log ("SENSOR", "Task stopping");

      if Is_Open (Scenario_File) then
         Close (Scenario_File);
      end if;

      if Trace_Enabled and then Is_Open (Trace_File) then
         Close (Trace_File);
      end if;
   exception
      when E : others =>
         Log_Cycle_Exception ("Task shutdown failure", E);
         Autopilot_System.Mark_Run_Failed;
         Autopilot_System.Mark_Scenario_Complete;
         if Is_Open (Scenario_File) then
            Close (Scenario_File);
         end if;
         if Trace_Enabled and then Is_Open (Trace_File) then
            Close (Trace_File);
         end if;
   end Sensor_Task;

end Autopilot_System.IO.Sensors;
