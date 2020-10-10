library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hdmi2csi is
  port (
    aclk            : in  std_logic;
    aresetn         : in  std_logic;
    -- S_AXIS
    s_axis_tvalid   : in  std_logic;
    s_axis_tready   : out std_logic;
    s_axis_tdata    : in  std_logic_vector (47 downto 0);
    s_axis_tstrb    : in  std_logic_vector (5 downto 0);
    s_axis_tkeep    : in  std_logic_vector (5 downto 0);
    s_axis_tlast    : in  std_logic;
    s_axis_tid      : in  std_logic_vector (0 downto 0);
    s_axis_tdest    : in  std_logic_vector (0 downto 0);
    s_axis_tuser    : in  std_logic_vector (0 downto 0);
    -- M_AXIS
    m_axis_tdata    : out std_logic_vector (87 downto 0);
    m_axis_tdest    : out std_logic_vector ( 1 downto 0);
    m_axis_tkeep    : out std_logic_vector (10 downto 0);
    m_axis_tlast    : out std_logic;
    m_axis_tready   : in  std_logic;
    m_axis_tuser    : out std_logic_vector (95 downto 0);
    m_axis_tvalid   : out std_logic;
    -- Debug
    oDebug          : out std_logic_vector (17 downto 0)
  );
end hdmi2csi;

architecture arc of hdmi2csi is
  -- components
  
  -- signals
  signal sCntStop     :std_logic := '0';
  signal sCntEn       :std_logic := '0';
  signal sWordCnt     :std_logic_vector (15 downto 0) := (0 => '1', others => '0');
  signal sWordCntReg  :std_logic_vector (15 downto 0);
  
  -- Debug
  signal axisDebug    :std_logic_vector (511 downto 0);

begin
  -- CSI-2 TX Pixel Encoding for Dual Pixel per Beat
  m_axis_tdata(87 downto 84) <= (others => '0');
  m_axis_tdata(83 downto 76) <= s_axis_tdata(47 downto 40);
  m_axis_tdata(75 downto 70) <= (others => '0');
  m_axis_tdata(69 downto 62) <= s_axis_tdata(39 downto 32);
  m_axis_tdata(61 downto 56) <= (others => '0');
  m_axis_tdata(55 downto 48) <= s_axis_tdata(31 downto 24);
  m_axis_tdata(47 downto 42) <= (others => '0');
  m_axis_tdata(41 downto 34) <= s_axis_tdata(23 downto 16);
  m_axis_tdata(33 downto 28) <= (others => '0');
  m_axis_tdata(27 downto 20) <= s_axis_tdata(15 downto  8);
  m_axis_tdata(19 downto 14) <= (others => '0');
  m_axis_tdata(13 downto  6) <= s_axis_tdata( 7 downto  0);
  m_axis_tdata( 5 downto  0) <= (others => '0');
  --
  m_axis_tvalid              <= s_axis_tvalid; --  when sCntStop = '1' else '0';
  s_axis_tready              <= m_axis_tready; --  when sCntStop = '1' else '1';
  m_axis_tlast               <= s_axis_tlast; --  when sCntStop = '1' else '0';
  m_axis_tdest               <= "00";
  m_axis_tkeep               <= (others => '1');
  m_axis_tuser(95 downto 64) <= (others => '0');
  m_axis_tuser(63 downto 48) <= sWordCntReg(13 downto 0) & "00";--x"1E00";--x"0f00";--x"1680"--x"03c0"; --sWordCnt;
  m_axis_tuser(47 downto 32) <= (others => '0');
  m_axis_tuser(31 downto 16) <= (others => '0');
  m_axis_tuser(15 downto  7) <= (others => '0');
  m_axis_tuser( 6 downto  1) <= "01"&x"E"; -- "02"&x"4";
  m_axis_tuser(0)            <=  s_axis_tuser(0); -- when sCntStop = '1' else '0';
  

  wordCntProc : process (aclk)
  begin
  if rising_edge(aclk) then
    if (aresetn = '0') then
      sCntEn      <= '0';
      sCntStop    <= '0';
      sWordCnt    <= (0 => '1', others => '0');
    else
      if (sCntStop = '0' and s_axis_tvalid = '1') then
        if (s_axis_tlast = '1') then
          if (sCntEn = '1') then
            sCntStop <= '1';
          else
            sCntEn   <= '1';
          end if;
        end if;
      end if;
      --
      if (m_axis_tready = '1' and s_axis_tvalid = '1') then
        if (s_axis_tlast = '1') then
          sWordCnt    <= (0 => '1', others => '0');
          sWordCntReg <= sWordCnt;
        else
          sWordCnt <= std_logic_vector(unsigned(sWordCnt) + 1);
        end if;
      end if;
    end if;
  end if;
  end process wordCntProc;
  --
  -- vcom l:/prj/hdl/hdmi2csi.vhd
  oDebug(0)           <= sCntStop;
  oDebug(1)           <= sCntEn;
  oDebug(17 downto 2) <= sWordCntReg;
end arc; 