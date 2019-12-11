--------------------------------------------------------------------------------
--  ПРОШИВКА ПЛИС ДЛЯ УСТРОЙСТВА: "ZXKit1 - ПЛАТА VGA & PAL"                  --                        
--  ВЕРСИЯ:  V2.0.9.02                                          ДАТА: 100304  --
--  АВТОР:   САБИРЖАНОВ ВАДИМ                                                 --
--  Modified by: Andy Karpov 2019-10-23                                       --
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;


entity vga_pal is
	port
	(

--------------------------------------------------------------------------------
--                 ВХОДНЫЕ СИГНАЛЫ ПЛИС СО СПЕКТРУМА                  091103  --
--------------------------------------------------------------------------------

R_IN        : in std_logic := '1'; -- цифровой RED
G_IN        : in std_logic := '1'; -- цифровой GREEN
B_IN        : in std_logic := '1'; -- цифровой BLUE
I_IN        : in std_logic := '1'; -- цифровой BRIGHT

SYNC_IN      : in std_logic := '1'; -- кадровые синхроимпульсы

F28			: in std_logic := '1';
F14 			: in std_logic := '1';

--------------------------------------------------------------------------------
--                     ВЫХОДНЫЕ ПОРТЫ ПЛИС ДЛЯ VGA                    090728  --
--------------------------------------------------------------------------------

R_VGA      : out std_logic := '0'; -- цифровой RED
G_VGA      : out std_logic := '0'; -- цифровой GREEN
B_VGA      : out std_logic := '0'; -- цифровой BLUE
I_VGA      : out std_logic_vector (2 downto 0) := "000"; -- выходы яркости VGA

VSYNC_VGA  : out std_logic := '1'; -- кадровые синхроимпульсы/синхроимп. SCART
HSYNC_VGA  : out std_logic := '1'; -- строчные синхроимпульсы/enable RGB SCART

--------------------------------------------------------------------------------
--                     ВЫХОДНЫЕ ПОРТЫ ПЛИС ДЛЯ ОЗУ                    100304  --
--------------------------------------------------------------------------------
A          : out std_logic_vector(14 downto 0); -- ША
WE         : out std_logic := '1'; -- сигнал записи в  ОЗУ  


--------------------------------------------------------------------------------
--                  ДВУНАПРАВЛЕННЫЕ ПОРТЫ ПЛИС ДЛЯ ОЗУ                090821  --
--------------------------------------------------------------------------------
D          : inout std_logic_vector(7 downto 0) := "ZZZZZZZZ" -- ШД

	);
    end vga_pal;
architecture RTL of vga_pal is

--------------------------------------------------------------------------------
--                       ВНУТРЕННИЕ СИГНАЛЫ ПЛИС                      090804  --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   НОРМАЛИЗОВАННЫЕ ВХОДНЫЕ СИГНАЛЫ                  090805  --
--------------------------------------------------------------------------------

signal R      : std_logic; -- цифровой RED
signal G      : std_logic; -- цифровой GREEN
signal B      : std_logic; -- цифровой BLUE
signal I      : std_logic; -- цифровой BRIGHT
signal RGBI_CLK : std_logic; -- тактовый сигнал входного кода цвета

signal KSI    : std_logic; -- кадровые синхроимпульсы
signal SSI    : std_logic; -- строчные синхроимпульсы

--------------------------------------------------------------------------------
--                     ПРОМЕЖУТОЧНЫЕ ДАННЫЕ ЦВЕТА                     100304  --
--------------------------------------------------------------------------------
signal R3          : std_logic; -- цифровой RED      -- при чтении из регистра
signal G3          : std_logic; -- цифровой GREEN
signal B3          : std_logic; -- цифровой BLUE
signal I3          : std_logic; -- цифровой BRIGHT

--------------------------------------------------------------------------------
--                     СИГНАЛЫ ДЛЯ СБРОСА СЧЕТЧИКОВ                   091220  --
--------------------------------------------------------------------------------

--signal KSI_1  : std_logic; -- выборка кадрового синхроимпульса
signal KSI_2  : std_logic; -- задержанные кадровые синхроимпульсы
signal SSI_2  : std_logic; -- задержанные строчные синхроимпульсы

--------------------------------------------------------------------------------
--              СЧЕТЧИКИ И ПАРАМЕТРЫ РАЗВЕРТКИ ДЛЯ VGA И VIDEO        091223  --
--------------------------------------------------------------------------------
-- строчная развертка VGA:

signal VGA_H_CLK     : std_logic; -- сигнал увеличения счетчика тактов в строке
signal VGA_H         : std_logic_vector(8 downto 0); -- счетчик тактов в строке
signal VGA_H_MIN     : std_logic_vector(8 downto 0); -- мин. знач.счетч. тактов
signal VGA_H_MAX     : std_logic_vector(8 downto 0); -- макс.знач.счетч. тактов
signal VGA_SSI1_BGN   : std_logic_vector(9 downto 0); -- начало строчного СИ
signal VGA_SSI1_END   : std_logic_vector(9 downto 0); -- конец  строчного СИ
signal VGA_SSI2_BGN   : std_logic_vector(9 downto 0); -- начало строчного СИ
signal VGA_SSI2_END   : std_logic_vector(9 downto 0); -- конец  строчного СИ
signal VGA_SGI1_BGN   : std_logic_vector(9 downto 0); -- начало строчного ГИ
signal VGA_SGI1_END   : std_logic_vector(9 downto 0); -- конец  строчного ГИ
signal VGA_SGI2_BGN   : std_logic_vector(9 downto 0); -- начало строчного ГИ
signal VGA_SGI2_END   : std_logic_vector(9 downto 0); -- конец  строчного ГИ
--------------------------------------------------------------------------------
-- кадровая развертка VGA:

signal VGA_V_CLK     : std_logic; -- сигнал увеличения счетчика строк в кадре
signal VGA_V         : std_logic_vector(9 downto 0); -- счетчик строк в кадре
signal VGA_V_MIN     : std_logic_vector(9 downto 0); -- мин. знач.счетчика строк
signal VGA_V_MAX     : std_logic_vector(9 downto 0); -- макс.знач.счетчика строк
signal VGA_KSI_BGN   : std_logic_vector(9 downto 0); -- начало кадрового СИ
signal VGA_KSI_END   : std_logic_vector(9 downto 0); -- конец  кадрового СИ
signal VGA_KGI1_END  : std_logic_vector(9 downto 0); -- конец  кадрового ГИ
signal VGA_KGI2_BGN  : std_logic_vector(9 downto 0); -- начало кадрового ГИ
--------------------------------------------------------------------------------
-- строчная развертка VIDEO:

signal VIDEO_H_CLK   : std_logic; -- сигнал увеличения счетчика тактов в строке
signal VIDEO_H       : std_logic_vector(9 downto 0); -- счетчик тактов в строке
signal VIDEO_H_MAX   : std_logic_vector(9 downto 0); -- макс.знач. счетч. тактов
signal VIDEO_SSI_BGN : std_logic_vector(9 downto 0); -- начало строчного СИ
signal VIDEO_SSI_END : std_logic_vector(9 downto 0); -- конец  строчного СИ
signal VIDEO_SGI_BGN : std_logic_vector(9 downto 0); -- начало строчного ГИ
signal VIDEO_SGI_END : std_logic_vector(9 downto 0); -- конец  строчного ГИ
--------------------------------------------------------------------------------
-- кадровая развертка VIDEO:

signal VIDEO_V_CLK   : std_logic;  --сигнал увеличения счетчика строк в кадре
signal VIDEO_V       : std_logic_vector(8 downto 0); -- счетчик строк в кадре
signal VIDEO_V_MAX   : std_logic_vector(8 downto 0); -- макс.знач. счетч. тактов
signal VIDEO_KSI_BGN : std_logic_vector(8 downto 0); -- начало кадрового СИ
signal VIDEO_KSI_END : std_logic_vector(8 downto 0); -- конец  кадрового СИ
signal VIDEO_KGI_BGN : std_logic_vector(8 downto 0); -- начало кадрового ГИ
signal VIDEO_KGI_END : std_logic_vector(8 downto 0); -- конец  кадрового ГИ
signal SCREEN_V_END  : std_logic_vector(8 downto 0); -- конец акт. части экрана
--------------------------------------------------------------------------------
-- тип компьютера/параметры развертки в строке: 

signal H_TYPE : std_logic_vector(1 downto 0); 
                
                --  10 - стандартная или удвоенная частота точек
                --       графики клонов "Спектрум", кварц на 14 МГц
                --       в строке 896 тактов (895 = 1 10 1111111)
                
                --  01 - режим графики "Профи", кварц на 12 МГц
                --       в строке 768 тактов (767 = 1 01 1111111)

                --  00 - режим графики "Орион", кварц на 10 МГц
                --       в строке 640 тактов (639 = 1 00 1111111)

                --  11 - режим графики "Специалист", кварц на 8 МГц
                --       в строке 512 тактов (511 = 0 11 1111111)
--------------------------------------------------------------------------------
--signal V_TYPE : std_logic; -- тип экрана по-вертикали / число строк в кадре: 
                --   0 - 312 строк (311 = 10011 0 111)
                --   1 - 320 строк (319 = 10011 1 111)

--------------------------------------------------------------------------------
--                     СИНХРОИМПУЛЬСЫ ДЛЯ VGA И VIDEO                 091220  --
--------------------------------------------------------------------------------

signal VGA_KSI      : std_logic; -- кадровые синхроимпульсы для VGA
signal VGA_SSI      : std_logic; -- строчные синхроимпульсы для VGA

signal VIDEO_KSI    : std_logic; -- кадровые синхроимпульсы для VIDEO
signal VIDEO_SSI1   : std_logic; -- основные строчные синхроимпульсы для VIDEO
signal VIDEO_SSI2   : std_logic; -- строчные синхроимпульсы - врезки для VIDEO
signal VIDEO_SYNC   : std_logic; -- синхросмесь для VIDEO

signal VGA_RBGI_CLK : std_logic; -- синхроимпульсы для вывода на VGA 

signal RESET_ZONE   : std_logic; -- сигнал для синхроницации счетчика тактов
signal RESET_H      : std_logic; -- если 0, то можно сбрасывать счетчик тактов    
signal RESET_V      : std_logic; -- если 0, то можно сбрасывать счетчик строк    
 
--------------------------------------------------------------------------------
--                    ГАСЯЩИЕ ИМПУЛЬСЫ ДЛЯ VGA И VIDEO                091102  --
--------------------------------------------------------------------------------

signal VGA_KGI      : std_logic; -- кадровые гасящие импульсы для VGA
signal VGA_SGI      : std_logic; -- строчные гасящие импульсы для VGA
signal VGA_BLANK    : std_logic; -- гасящие импульсы для VGA

signal VIDEO_KGI    : std_logic; -- кадровые гасящие импульсы для VIDEO
signal VIDEO_SGI    : std_logic; -- строчные гасящие импульсы для VIDEO
signal VIDEO_BLANK  : std_logic; -- гасящие импульсы для VIDEO

--------------------------------------------------------------------------------
--                РЕГИСТР ДЛЯ ЗАПИСИ ПО 2 ТОЧКИ В ОЗУ            090821  --
--------------------------------------------------------------------------------

signal WR_REG       : std_logic_vector(7 downto 0); -- биты 3-R, 2-G, 1-B, 0-I

--------------------------------------------------------------------------------
--                РЕГИСТР ДЛЯ ЧТЕНИЯ ПО 2 ТОЧКИ В ОЗУ            100304  --
--------------------------------------------------------------------------------

signal RD_REG       : std_logic_vector(7 downto 0); -- биты 3-R, 2-G, 1-B, 0-I

begin

--------------------------------------------------------------------------------
--                            ПРОЦЕССЫ                                        --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--                   НОРМАЛИЗАЦИЯ ВХОДНЫХ СИГНАЛОВ                    090826  --
--------------------------------------------------------------------------------

-- если соответствующая перемычка/тумблер находится в положении ON, 
-- что соответствует логическому нулю, соответствующий сигнал инвертируется.
-- затем код цвета тактируются
--------------------------------------------------------------------------------
RGBI_CLK <= F14; -- нормализация тактовых синхроимпульсов
--------------------------------------------------------------------------------
process (RGBI_CLK)   
begin
  if (falling_edge(RGBI_CLK)) then -- если спад тактового импульса
--------------------------------------------------------------------------------
        B   <=   B_IN;    -- остальные строки - со Спектрума
        R   <=   R_IN; 
        G   <=   G_IN;
        I   <=   I_IN;
  end if;
end process;

--------------------------------------------------------------------------------
--              ФОРМИРОВАНИЕ СИГНАЛОВ ДЛЯ СБРОСА СЧЕТЧИКОВ            100304  --
--------------------------------------------------------------------------------
process (F14, VIDEO_H(8),VIDEO_H(9))
begin

  if (rising_edge(F14)) then  -- если фронт тактового импульса, переход из 0 в 1
      SSI   <= SYNC_IN;
      SSI_2 <= not SSI;       -- задержка на такт строчного синхроимпульса
  end if;

  -- выборка состояния кадрового синхроимпульса во время 1/4...1/2 строки VIDEO
  if (rising_edge(VIDEO_H(8)) and VIDEO_H(9)='0') then
      KSI   <= SYNC_IN;
      KSI_2 <= not KSI;       -- задержка кадрового синхроимпульса на строку 
  end if;
end process;

RESET_H <= SSI or SSI_2;      -- если 0, то можно сбрасывать счетчик тактов    
RESET_V <= KSI or KSI_2;      -- если 0, то можно сбрасывать счетчик строк
-- зона для сброса счетчиков, 0 в средней части экрана по-вертикали
RESET_ZONE <= (not VIDEO_V(7) or VIDEO_V(8)); 

VGA_V_CLK   <= (VGA_H(7)   or VGA_H(8));
VIDEO_V_CLK <= (VIDEO_H(8) or VIDEO_H(9));


--------------------------------------------------------------------------------
--              ЗАПОМИНАНИЕ КОЛИЧЕСТВА СТРОК В КАДРЕ                  091016  --
--------------------------------------------------------------------------------
--process (KSI)
--begin
--  if (falling_edge(KSI)) then -- если спад  строчного синхроимпульса,
--    V_TYPE <= VIDEO_V(3); -- упрощенно запоминает состояние счетчика строк VIDEO
--                          -- 0 = 312 строк, 1 = 320 строк
--  end if;
--end process;
--

--------------------------------------------------------------------------------
--                 УПРАВЛЕНИЕ СЧЕТЧИКАМИ ТАКТОВ В СТРОКАХ             100304  --
--------------------------------------------------------------------------------
process (F14, SSI, SSI_2)
begin  
  if (falling_edge(SSI)) then -- если спад  строчного синхроимпульса,
    if RESET_ZONE = '0'  then -- если зона для сброса счетчиков
      -- запоминаем состояние вспомогательного счетчика тактов в строке
--      VIDEO_H_MAX <= VIDEO_H;
      VGA_H_MAX  <= (VIDEO_H(9 downto 1) );
    end if;
  end if;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
  if (falling_edge(F14)) then         -- по спаду тактового импульса:
--------------------------------------------------------------------------------
    if (RESET_H = '0')  then          -- если спад входного синхросигнала,
      VIDEO_H <= (others => '0');     -- обнуляем вспомогательный счетчик тактов
    else 
      VIDEO_H <= VIDEO_H + 1;         -- иначе - увеличиваем его
    end if;   
--------------------------------------------------------------------------------
    -- если начало строчного СИ и строка в средней части экрана по-вертикали:
    -- синхронизируем счетчики тактов с входными синхроимпульсами
    -- или, если последняя точка в строке VGA,
    if ((RESET_H or RESET_ZONE) = '0') or (VGA_H = VGA_H_MAX)  then
      VGA_H   <= (others => '0');     -- обнуляем счетчик тактов VGA
    else
      VGA_H   <= VGA_H   + 1;         -- иначе - увеличиваем счетчик точек VGA
    end if;   
  end if;   
end process;

--------------------------------------------------------------------------------
--                 УПРАВЛЕНИЕ СЧЕТЧИКАМИ СТРОК В КАДРЕ                091223  --
--------------------------------------------------------------------------------
-- чтобы не было смещения экрана вниз при частоте VGA 60 Гц 
-- пропускаются 29.5 строк экрана Спектрума сверху экрана, 
-- что соответствует 59 строкам VGA.


process (VGA_H(8), VIDEO_H(9), VGA_V_CLK, VIDEO_V_CLK)
begin
--------------------------------------------------------------------------------
-- счетчик строк VGA:
  if (falling_edge(VGA_V_CLK)) then  -- по спаду сигнала увеличения счетч. строк
      if (RESET_V) = '0' then        -- если начало кадрового синхроимпульса:
        VGA_V <= (others => '0');    -- обнуляем счетчик строк VGA
      else                           -- иначе 
        VGA_V <= VGA_V   + 1;        -- увеличиваем счетчик строк VGA
      end if;    
  end if;    
--------------------------------------------------------------------------------
-- счетчик строк VIDEO:
  if (falling_edge(VIDEO_V_CLK)) then -- по спаду сигнала увеличения счетч.строк
    if (RESET_V) = '0' then           -- если начало кадрового синхроимпульса:
      VIDEO_V <= (others => '0');     -- обнуляем счетчик строк VIDEO
    else    
      VIDEO_V <= VIDEO_V + 1;         -- увеличиваем счетчик строк VIDEO
    end if;    
  end if;    
-------------------------------------------------------------------------------
end process;

--------------------------------------------------------------------------------
--                       ОПРЕДЕЛЕНИЕ ТИПА КВАРЦА                      100304  --
--------------------------------------------------------------------------------
-- если перемычки JP6 (SET_FK_IN) и JP5 (VGA_SCART) сняты, 
-- частота кварца определяется автоматически.
-- если одна из них или обе перемычки установлены, частота выбирается ими

-- соответсвие битов (перемычка снята, 0 - установлена) :
--                --  10 - стандартная или удвоенная частота точек
--                --       графики клонов "Спектрум", кварц на 14 МГц
--                --       в строке 896 тактов (895 = 1 10 1111111)
--                
--                --  01 - режим графики "Профи", кварц на 12 МГц
--                --       в строке 768 тактов (767 = 1 01 1111111)
--
--                --  00 - режим графики "Орион", кварц на 10 МГц
--                --       в строке 640 тактов (639 = 1 00 1111111)
--
--                --  11 - режим графики "Специалист", кварц на 8 МГц
--                --       в строке 512 тактов (511 = 0 11 1111111)
--process (H_TYPE)                   
--begin
--    H_TYPE(1) <= VGA_H_MAX(7); -- автоматическое определение частоты
--    H_TYPE(0) <= VGA_H_MAX(6);
--    H_TYPE(1) <= SET_FK_IN;    -- частота задается перемычками
--    H_TYPE(0) <= VGA_SCART;
--end process;

--H_TYPE(1) <= VGA_H_MAX(7);
--H_TYPE(0) <= VGA_H_MAX(6);
--H_TYPE(1) <= (VGA_H_MAX(7) or SET_FK_IN);
--H_TYPE(0) <= (VGA_H_MAX(6) or VGA_SCART);

H_TYPE <= "10";

--------------------------------------------------------------------------------
--                ФОРМИРОВАНИЕ ПАРАМЕТРОВ РАЗВЕРТКИ VGA               100304  --
--------------------------------------------------------------------------------

-- строчные синхроимпульсы для VGA:

process (H_TYPE)                   
begin
  case H_TYPE is
 
    when "10" =>   -- "Спектрум"
      -- строчная развертка VGA:
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000100110"; --  38 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "1101110010"; -- 882 - начало 2 строчного СИ
      VGA_SSI2_END <= "1101111111"; -- 895 - конец  2 строчного СИ
      VGA_SGI1_END <= "0001000001"; --  65 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "1101110010"; -- 882 - начало 2 строчного ГИ

    when "01" =>   -- "Профи"
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000100010"; --  34 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "1011110101"; -- 757 - начало 2 строчного СИ
      VGA_SSI2_END <= "1011111111"; -- 767 - конец  2 строчного СИ
      VGA_SGI1_END <= "0000111001"; --  57 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "1011101101"; -- 749 - начало 2 строчного ГИ

    when "00" =>   -- "Орион"
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000100101"; --  37 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "0000000000"; --   0 - начало 2 строчного СИ
      VGA_SSI2_END <= "0000100101"; --  37 - конец  2 строчного СИ
      VGA_SGI1_END <= "0000111000"; --  56 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "1001111010"; -- 634 - начало 2 строчного ГИ

    when "11" =>   -- "Специалист"
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000010001"; --  17 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "0111110011"; -- 499 - начало 2 строчного СИ
      VGA_SSI2_END <= "0111111111"; -- 511 - конец  2 строчного СИ
      VGA_SGI1_END <= "0000100000"; --  32 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "0111101110"; -- 494 - начало 2 строчного ГИ

  end case;
end process;
--------------------------------------------------------------------------------
-- кадровая развертка VGA:

-- чтобы не было смещения экрана вниз при частоте VGA 60 Гц 
-- пропускаются 32 строки экрана Спектрума сверху экрана, 
-- что соответствует 64 строкам VGA.

VGA_KSI_BGN  <= "0000001011"; --  11 - начало кадрового СИ
VGA_KSI_END  <= "0000001100"; --  12 - конец  кадрового СИ
VGA_KGI1_END <= "0000101100"; --  44 - конец  кадрового ГИ
VGA_KGI2_BGN <= "1001110001"; -- 625 - начало кадрового ГИ

--------------------------------------------------------------------------------
--                   ФОРМИРОВАНИЕ СТРОЧНЫХ ИМПУЛЬСОВ VGA              091223  --
--------------------------------------------------------------------------------
-- основные строчные синхроимпульсы для VIDEO
VGA_SSI  <= '0' when (VGA_H >= VGA_SSI1_BGN and VGA_H <= VGA_SSI1_END) 
                  or (VGA_H >= VGA_SSI2_BGN and VGA_H <= VGA_SSI2_END) 
                else '1';

-- строчные гасящие импульсы для VIDEO
VGA_SGI  <= '0' when (VGA_H <= VGA_SGI1_END)
                  or (VGA_H >= VGA_SGI2_BGN)
                else '1';

--------------------------------------------------------------------------------
--                   ФОРМИРОВАНИЕ КАДРОВЫХ ИМПУЛЬСОВ VGA              091223  --
--------------------------------------------------------------------------------
-- кадровые синхроимпульсы для VIDEO
VGA_KSI  <= '0' when (VGA_V >= VGA_KSI_BGN) 
                 and (VGA_V <= VGA_KSI_END) 
                else '1';
-- кадровые гасящие импульсы для VIDEO
VGA_KGI  <= '0' when (VGA_V <= VGA_KGI1_END) 
                  or (VGA_V >= VGA_KGI2_BGN )  
                else '1';
                  
--------------------------------------------------------------------------------
--                    ФОРМИРОВАНИЕ СТРОЧНЫХ ИМПУЛЬСОВ VIDEO           091223  --
--------------------------------------------------------------------------------

-- основные строчные синхроимпульсы для VIDEO:

                       -- клон Спектрума (14 МГц)
VIDEO_SSI1 <= '0' when (VIDEO_H > 20 and VIDEO_H < 87 and H_TYPE = "10")
                       -- Профи (12 МГц)
                    or (VIDEO_H > 17 and VIDEO_H < 75 and H_TYPE = "01")
                       -- Орион (10 МГц)
                    or (VIDEO_H > 14 and VIDEO_H < 62 and H_TYPE = "00")
                
                  else '1';

-- строчные синхроимпульсы - врезки для VIDEO:
                       -- клон Спектрума (14 МГц)
VIDEO_SSI2 <= '0' when (VIDEO_H > 20 and VIDEO_H < 851 and H_TYPE = "10")
                       -- Профи (12 МГц)
                    or (VIDEO_H > 17 and VIDEO_H < 729 and H_TYPE = "01")
                       -- Орион (10 МГц)
                    or (VIDEO_H > 14 and VIDEO_H < 608 and H_TYPE = "00")
                
                  else '1';

-- строчные гасящие импульсы для VIDEO:
                       -- клон Спектрума (14 МГц)
VIDEO_SGI  <= '0' when (VIDEO_H < 168 and H_TYPE = "10")
                       -- Профи (12 МГц)
                    or (VIDEO_H < 144 and H_TYPE = "01")
                       -- Орион (10 МГц)
                    or (VIDEO_H < 120 and H_TYPE = "00")
                
                  else '1';

--------------------------------------------------------------------------------
--                   ФОРМИРОВАНИЕ КАДРОВЫХ ИМПУЛЬСОВ VIDEO            091103  --
--------------------------------------------------------------------------------
-- кадровые синхроимпульсы для VIDEO
VIDEO_KSI  <= '0' when VIDEO_V < 4 else '1';

-- кадровые гасящие импульсы для VIDEO
VIDEO_KGI  <= '0' when VIDEO_V < 16 else '1';


--------------------------------------------------------------------------------
--                    ФОРМИРОВАНИЕ СИНХРОСМЕСИ ДЛЯ VIDEO              090820  --
--------------------------------------------------------------------------------
VIDEO_SYNC <= VIDEO_SSI2 when VIDEO_KSI = '0' else VIDEO_SSI1;

--------------------------------------------------------------------------------
--                    ФОРМИРОВАНИЕ СМЕСИ ГАСЯЩИХ ИМПУЛЬСОВ            100304  --
--------------------------------------------------------------------------------
---- гасящие импульсы для VGA
--VGA_BLANK   <= VGA_KGI and VGA_SGI;

---- гасящие импульсы для VIDEO
--VIDEO_BLANK <= VIDEO_KGI and VIDEO_SGI;

--------------------------------------------------------------------------------
--                     МУЛЬТИПЛЕКСИРОВАНИЕ АДРЕСОВ ОЗУ                090812  --
--------------------------------------------------------------------------------

-- если цикл записи и выходная частота кадров 50/48 Гц:
A <= "00000" & VIDEO_V(0) & VIDEO_H(9 downto 1) when (F14='1')
-- если цикл чтения и выходная частота кадров 50/48 Гц:
else "00000" & (not VIDEO_V(0)) & VGA_H(8 downto 0);

--------------------------------------------------------------------------------
--                       ПЕРЕДАЧА ДАННЫХ ЧЕРЕЗ ОЗУ                    100304  --
--------------------------------------------------------------------------------
-- управление выводом на шину данных (запись произойдет по фронту WE) 
D(7 downto 0) <= WR_REG when F14 = '1' else (others => 'Z');

process (F28, F14, VIDEO_H(0))                   
begin
  if (rising_edge(F14)) then -- по фронту 
--------------------------------------------------------------------------------
    -- запись кода 2 точек VIDEO в регистр перед записью сразу 8 bit в ОЗУ:
    case VIDEO_H(0) is
      when '1' =>      
        WR_REG(3 downto  0) <= R & G & B & I; -- запись точки во вторую тетраду
      when '0' =>      
        WR_REG(7 downto  4) <= R & G & B & I; -- запись точки в  первую тетраду
    end case;
--------------------------------------------------------------------------------
  end if;

  if (rising_edge(F28) and F14='0') then -- по фронту OE
      -- чтение кода двух точек из ОЗУ в регистр для вывода на VGA
      RD_REG(7 downto 0) <= D(7 downto 0);

--------------------------------------------------------------------------------
  end if;

end process;


--------------------------------------------------------------------------------
--                  ФОРМИРОВАНИЕ СИГНАЛОВ УПРАВЛЕНИЯ ОЗУ              100304  --
--------------------------------------------------------------------------------

-- сигнал записи в  ОЗУ  
WE <= not F14;

--------------------------------------------------------------------------------
--                      ВЫВОД СИГНАЛОВ НА ГНЕЗДО VGA                  090826  --
--------------------------------------------------------------------------------

-- разделение точек из регистра после чтения из ОЗУ:

process (F28, F14) 
begin
  if (rising_edge(F28)) then
		if F14 = '0' then 
			R3 <= RD_REG(3);
			G3 <= RD_REG(2);
			B3 <= RD_REG(1);
			I3 <= RD_REG(0);
		else 
			R3 <= RD_REG(7);
			G3 <= RD_REG(6);
			B3 <= RD_REG(5);
			I3 <= RD_REG(4);
		end if;
	end if;
end process;

--------------------------------------------------------------------------------
-- синхронизация гасящих импульсов и вывод синхроимпульсов

process (F14) 
begin
  if (rising_edge(F14)) then  -- если фронт тактового импульса, переход из 0 в 1

    -- гасящие импульсы для VGA
    VGA_BLANK   <= VGA_KGI and VGA_SGI;

    ---- гасящие импульсы для VIDEO
    VIDEO_BLANK <= VIDEO_KGI and VIDEO_SGI;
      

    VSYNC_VGA <= VGA_KSI;      -- кадровые синхроимпульсы для VGA
    HSYNC_VGA <= VGA_SSI;      -- строчные синхроимпульсы для VGA
      
  end if;
end process;

--------------------------------------------------------------------------------

-- удвоение частоты с помощью задержанного сигнала
VGA_RBGI_CLK <= F28;
      
--------------------------------------------------------------------------------
--                      вывод RGBI на разъем VGA                      100304  --
--------------------------------------------------------------------------------
process (VGA_RBGI_CLK) 
begin
  if (rising_edge(VGA_RBGI_CLK)) then  -- если фронт тактового импульса,

    R_VGA     <= R3 and VGA_BLANK;
    G_VGA     <= G3 and VGA_BLANK;
    B_VGA     <= B3 and VGA_BLANK;
    
    if (I3 and VGA_BLANK) = '0'  then  -- если яркость пониженная:
        I_VGA <= "000";          -- уменьшаем сигнал подключением резисторов к 0
    else
		   
        I_VGA <= "ZZZ";          -- резисторы отключены
    end if;

  end if;
end process;

end RTL;
