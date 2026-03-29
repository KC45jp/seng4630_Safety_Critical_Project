with ada.Text_IO; use Ada.Text_IO;
with ada.numerics.discrete_random;

procedure RandTest is
   type randRange is new Integer range 1..100;
   package Rand_Int is new ada.numerics.discrete_random(randRange);
   use Rand_Int;
   gen : Generator;
   num : randRange;
begin
   Reset(gen);
   num := random(gen);
   Put_line(randRange'Image(num));
end RandTest;