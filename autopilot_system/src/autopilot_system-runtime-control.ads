package Autopilot_System.Runtime.Control is

   --  Periodic control task (100 ms cycle).
   --  Computes actuator outputs based on the current state and sensor data.

   type Immediate_Output_Mode is (IDLE_NOW, EMERGENCY_NOW);

   procedure Apply_Immediate_Output (Mode : in Immediate_Output_Mode);

   task type Control_Task is
      entry Start;
      entry Stop;
   end Control_Task;

end Autopilot_System.Runtime.Control;
