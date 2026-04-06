package Autopilot_System.Runtime.Control is

   --  Periodic control task (100 ms cycle).
   --  Computes actuator outputs based on the current state and sensor data.

   task type Control_Task is
      entry Start;
      entry Stop;
   end Control_Task;

end Autopilot_System.Runtime.Control;
