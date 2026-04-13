with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Autopilot_System is

   Stored_Scenario_Path : Unbounded_String := To_Unbounded_String ("");
   Stored_Trace_Path    : Unbounded_String := To_Unbounded_String ("");
   Scenario_Done        : Boolean := False;
   Run_Has_Failed       : Boolean := False;

   pragma Atomic (Scenario_Done);
   pragma Atomic (Run_Has_Failed);

   procedure Log (Source : String; Message : String) is
   begin
      Ada.Text_IO.Put_Line ("[" & Source & "] " & Message);
   end Log;

   procedure Configure_Run (Scenario_Path : String; Trace_Path : String := "") is
   begin
      Stored_Scenario_Path := To_Unbounded_String (Scenario_Path);
      Stored_Trace_Path    := To_Unbounded_String (Trace_Path);
      Scenario_Done        := False;
      Run_Has_Failed       := False;
   end Configure_Run;

   function Scenario_Path return String is
   begin
      return To_String (Stored_Scenario_Path);
   end Scenario_Path;

   function Trace_Path return String is
   begin
      return To_String (Stored_Trace_Path);
   end Trace_Path;

   procedure Mark_Scenario_Complete is
   begin
      Scenario_Done := True;
   end Mark_Scenario_Complete;

   function Scenario_Complete return Boolean is
   begin
      return Scenario_Done;
   end Scenario_Complete;

   procedure Mark_Run_Failed is
   begin
      Run_Has_Failed := True;
   end Mark_Run_Failed;

   function Run_Failed return Boolean is
   begin
      return Run_Has_Failed;
   end Run_Failed;

end Autopilot_System;
