-----------------------------------------------------------------
--------------- Bus Package --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pBus_savestates is

   constant BUS_buswidth : integer := 64;
   constant BUS_busadr   : integer := 10;
  
end package;

-----------------------------------------------------------------
--------------- Reg Interface, verbose for Verilog --------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pBus_savestates.all;

entity eReg_SavestateV is
   generic
   (
      Adr       : integer range 0 to (2**BUS_busadr)-1;
      def       : std_logic_vector(BUS_buswidth-1 downto 0)
   );
   port 
   (
      clk       : in    std_logic;
      BUS_Din   : in    std_logic_vector(BUS_buswidth-1 downto 0);
      BUS_Adr   : in    std_logic_vector(BUS_busadr-1 downto 0);
      BUS_wren  : in    std_logic;
      BUS_rst   : in    std_logic;
      BUS_Dout  : out   std_logic_vector(BUS_buswidth-1 downto 0) := (others => '0');
      Din       : in    std_logic_vector(BUS_buswidth-1 downto 0);
      Dout      : out   std_logic_vector(BUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of eReg_SavestateV is

   signal Dout_buffer : std_logic_vector(BUS_buswidth-1 downto 0) := def;
    
   signal AdrI : std_logic_vector(BUS_Adr'left downto 0);
    
begin

   AdrI <= std_logic_vector(to_unsigned(Adr, BUS_Adr'length));

   process (clk)
   begin
      if rising_edge(clk) then
      
         if (BUS_rst = '1') then
         
            Dout_buffer <= def;
         
         else
      
            if (BUS_Adr = AdrI and BUS_wren = '1') then
               for i in 0 to BUS_buswidth-1 loop
                  Dout_buffer(i) <= BUS_Din(i);  
               end loop;
            end if;
          
         end if;
         
      end if;
   end process;
   
   Dout <= Dout_buffer;
   
   goutputbit: for i in 0 to BUS_buswidth-1 generate
      BUS_Dout(i) <= Din(i) when BUS_Adr = AdrI else '0';
   end generate;
   
end architecture;




