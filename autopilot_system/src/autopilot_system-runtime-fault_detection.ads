package Autopilot_System.Runtime.Fault_Detection is

   --  Periodic fault monitor (100 ms cycle).
   --  Reads sensor data, classifies faults by severity, and drives
   --  the system state machine.

   task type Fault_Detection_Task is
      entry Start;
      entry Stop;
   end Fault_Detection_Task;

end Autopilot_System.Runtime.Fault_Detection;
