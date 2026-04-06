with Ada.Text_IO;

package body Autopilot_System is

   procedure Log (Source : String; Message : String) is
   begin
      Ada.Text_IO.Put_Line ("[" & Source & "] " & Message);
   end Log;

end Autopilot_System;
