----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    23:12:12 10/24/2014 
-- Design Name: 
-- Module Name:    SevenSeg - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD;
use IEEE.NUMERIC_STD.ALL;
use work.all;
use work.types.all;
use work.topEntity_0;

--library UNISIM;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;



entity SevenSeg is
  port ( Seg7    : OUT STD_LOGIC_VECTOR(6 downto 0)
       ; Seg7_AN : OUT STD_LOGIC_VECTOR(3 downto 0)
       ; Seg7_DP : OUT STD_LOGIC
       ; Switch  : IN  STD_LOGIC_VECTOR(7 downto 0)
       ; Led     : OUT STD_LOGIC_VECTOR(7 downto 0)
       ; clk     : IN  STD_LOGIC
       );
end SevenSeg;

ARCHITECTURE Behavioral OF SevenSeg IS
  signal recordish : product2;
  signal clkin     : STD_LOGIC;
BEGIN
  t : entity topEntity_0 PORT MAP (
      system1000     => clkin
    , system1000_rst => '1'
    , topLet_o       => recordish
  );
  clkin   <= clk;
  Seg7_an <= toSLV(recordish.product2_sel0);
  Seg7    <= toSLV(recordish.product2_sel1);
  Seg7_DP <= '1';
  Led     <= Switch;
END Behavioral;

