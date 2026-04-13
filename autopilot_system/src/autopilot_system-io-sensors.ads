package Autopilot_System.IO.Sensors is

   --  Periodic sensor task (50 ms cycle).
   --  Generates simulated sensor readings and writes them to Vehicle_State.

   task type Sensor_Task is
      entry Start;
      entry Stop;
   end Sensor_Task;

end Autopilot_System.IO.Sensors;
