package body Autopilot_System.Vehicle_State is

   function More_Severe (Left, Right : Fault_Level) return Fault_Level is
   begin
      if Left >= Right then
         return Left;
      end if;

      return Right;
   end More_Severe;

   function Aggregate_Fault (Data : Sensor_Data) return Fault_Level is
   begin
      return More_Severe
        (More_Severe (Data.Speed.FLevel, Data.Front_Distance.FLevel),
         Data.Lane_Offset.FLevel);
   end Aggregate_Fault;

   protected body Vehicle_State_Object is
      procedure Update_Sensors (Data : in Sensor_Data) is
      begin
         Sensors := Data;
         Sensors.Overall_Fault := Aggregate_Fault (Sensors);
      end Update_Sensors;

      procedure Set_State (S : in System_State) is
      begin
         State := S;
      end Set_State;

      procedure Set_Fault (F : in Fault_Level) is
      begin
         Fault := F;
      end Set_Fault;

      function Get_Sensors return Sensor_Data is
      begin
         return Sensors;
      end Get_Sensors;

      function Get_State return System_State is
      begin
         return State;
      end Get_State;

      function Get_Fault return Fault_Level is
      begin
         return More_Severe (Fault, Sensors.Overall_Fault);
      end Get_Fault;
   end Vehicle_State_Object;

end Autopilot_System.Vehicle_State;
