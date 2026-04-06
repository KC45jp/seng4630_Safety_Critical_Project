--  Main entry point: launches all ADAS tasks and runs a simulation scenario.
--
--  Timeline:
--    t=0 s   Start all tasks (STANDBY)
--    t=1 s   ENGAGE autopilot
--    t=9 s   Check final state, OVERRIDE if not already stopped
--    t=9.5 s Stop all periodic tasks, exit

with Autopilot_System;
with Autopilot_System.Types;          use Autopilot_System.Types;
with Autopilot_System.Vehicle_State;
with Autopilot_System.Sensors;
with Autopilot_System.Fault_Detection;
with Autopilot_System.Control;
with Autopilot_System.Driver_Input;

procedure Main is
   Sensor : Autopilot_System.Sensors.Sensor_Task;
   Fault  : Autopilot_System.Fault_Detection.Fault_Detection_Task;
   Ctrl   : Autopilot_System.Control.Control_Task;
   Driver : Autopilot_System.Driver_Input.Driver_Input_Task;
begin
   Autopilot_System.Log ("MAIN", "========================================");
   Autopilot_System.Log ("MAIN", "  ADAS Simulation Starting");
   Autopilot_System.Log ("MAIN", "========================================");

   --  Start all concurrent tasks
   Sensor.Start;
   Fault.Start;
   Ctrl.Start;
   Driver.Start;

   Autopilot_System.Log ("MAIN", "All tasks running. System in STANDBY.");
   delay 1.0;

   --  Driver engages autopilot
   Autopilot_System.Log ("MAIN", ">>> Driver command: ENGAGE");
   Driver.Send_Command (ENGAGE);
   delay 8.0;

   --  Check the final state
   declare
      Final : constant System_State :=
        Autopilot_System.Vehicle_State.Shared.Get_State;
   begin
      Autopilot_System.Log
        ("MAIN", "Final state: " & System_State'Image (Final));

      if Final /= SAFE_STOP and Final /= STANDBY then
         Autopilot_System.Log ("MAIN", ">>> Driver command: OVERRIDE");
         Driver.Send_Command (OVERRIDE);
         delay 0.5;
      end if;
   end;

   --  Shut down periodic tasks
   Sensor.Stop;
   Fault.Stop;
   Ctrl.Stop;
   --  Driver_Input_Task terminates via 'terminate' alternative

   Autopilot_System.Log ("MAIN", "========================================");
   Autopilot_System.Log ("MAIN", "  Simulation Complete");
   Autopilot_System.Log ("MAIN", "========================================");
end Main;
