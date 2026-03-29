with Autopilot_System.Types; use Autopilot_System.Types;

package Autopilot_System.Vehicle_State is
   protected type Vehicle_State_Object is
      procedure Update_Sensors (Data : in Sensor_Data);
      procedure Set_State (S : in System_State);
      procedure Set_Fault (F : in Fault_Level);
      function Get_Sensors return Sensor_Data;
      function Get_State return System_State;
      function Get_Fault return Fault_Level;
   private
      Sensors : Sensor_Data :=
        (Speed => (Speed => 0.0, others => <>),
         Front_Distance => (Front_Distance => 100.0, others => <>),
         Lane_Offset => (Lane_Offset => 0.0, others => <>),
         Overall_Fault => NONE);
      State : System_State := STANDBY;
      Fault : Fault_Level := NONE;
   end Vehicle_State_Object;

   State : Vehicle_State_Object;
end Autopilot_System.Vehicle_State;
