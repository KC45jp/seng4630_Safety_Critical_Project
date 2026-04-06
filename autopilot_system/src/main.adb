with Ada.Command_Line;               use Ada.Command_Line;
with Ada.Strings.Unbounded;         use Ada.Strings.Unbounded;
with Autopilot_System;
with Autopilot_System.Runtime.Control;
with Autopilot_System.IO.Driver_Input;
with Autopilot_System.Runtime.Fault_Detection;
with Autopilot_System.IO.Sensors;
with Autopilot_System.Domain.Types;        use Autopilot_System.Domain.Types;
with Autopilot_System.Runtime.State;

procedure Main is
   Sensor : Autopilot_System.IO.Sensors.Sensor_Task;
   Fault  : Autopilot_System.Runtime.Fault_Detection.Fault_Detection_Task;
   Ctrl   : Autopilot_System.Runtime.Control.Control_Task;
   Driver : Autopilot_System.IO.Driver_Input.Driver_Input_Task;

   procedure Usage is
   begin
      Autopilot_System.Log
        ("MAIN",
         "Usage: main --scenario <path> [--trace-out <path>]");
   end Usage;

   function Configure_From_Arguments return Boolean is
      Scenario_Path : Unbounded_String := To_Unbounded_String ("");
      Trace_Path    : Unbounded_String := To_Unbounded_String ("");
      Index         : Natural := 1;
   begin
      while Index <= Argument_Count loop
         declare
            Arg : constant String := Argument (Index);
         begin
            if Arg = "--scenario" and then Index < Argument_Count then
               Scenario_Path := To_Unbounded_String (Argument (Index + 1));
               Index := Index + 2;
            elsif Arg = "--trace-out" and then Index < Argument_Count then
               Trace_Path := To_Unbounded_String (Argument (Index + 1));
               Index := Index + 2;
            else
               Autopilot_System.Log ("MAIN", "Unknown or incomplete argument: " & Arg);
               Usage;
               return False;
            end if;
         end;
      end loop;

      if Length (Scenario_Path) = 0 then
         Usage;
         return False;
      end if;

      Autopilot_System.Configure_Run
        (Scenario_Path => To_String (Scenario_Path),
         Trace_Path    => To_String (Trace_Path));
      return True;
   end Configure_From_Arguments;

begin
   if not Configure_From_Arguments then
      Set_Exit_Status (Failure);
      return;
   end if;

   Autopilot_System.Log ("MAIN", "========================================");
   Autopilot_System.Log ("MAIN", "  ADAS Scenario Replay Starting");
   Autopilot_System.Log ("MAIN", "========================================");
   Autopilot_System.Log ("MAIN", "Scenario: " & Autopilot_System.Scenario_Path);

   Sensor.Start;
   Fault.Start;
   Ctrl.Start;
   Driver.Start;

   while not Autopilot_System.Scenario_Complete loop
      delay 0.05;
   end loop;

   delay 0.20;

   Sensor.Stop;
   Fault.Stop;
   Ctrl.Stop;

   declare
      Final_State : constant System_State :=
        Autopilot_System.Runtime.State.Shared.Get_State;
      Final_Fault : constant Fault_Level :=
        Autopilot_System.Runtime.State.Shared.Get_Fault;
   begin
      Autopilot_System.Log
        ("MAIN", "Final state: " & System_State'Image (Final_State));
      Autopilot_System.Log
        ("MAIN", "Final fault: " & Fault_Level'Image (Final_Fault));
   end;

   if Autopilot_System.Run_Failed then
      Set_Exit_Status (Failure);
   else
      Set_Exit_Status (Success);
   end if;

   Autopilot_System.Log ("MAIN", "========================================");
   Autopilot_System.Log ("MAIN", "  Scenario Replay Complete");
   Autopilot_System.Log ("MAIN", "========================================");
end Main;
