--  Root package for the ADAS (Advanced Driver Assistance System).
--  Provides logging plus shared run configuration for scenario replay.

package Autopilot_System is

   procedure Log (Source : String; Message : String);

   procedure Configure_Run (Scenario_Path : String; Trace_Path : String := "");

   function Scenario_Path return String;
   function Trace_Path return String;

   procedure Mark_Scenario_Complete;
   function Scenario_Complete return Boolean;

   procedure Mark_Run_Failed;
   function Run_Failed return Boolean;

end Autopilot_System;
