# -*- perl -*-
#
###############################################################################
# This file is autogenerated by $0.  DO NOT EDIT!
###############################################################################
#
package Device::LaCrosse::WS23xx::MemoryMap;

use strict;
use warnings;

my $_memory_map = <<'END_MEMORY_MAP';
000F:1  Wind_unit                                0=m/s, 1=knots, 2=beaufort, 3=km/h, 4=mph
0266:1  LCD_contrast                             $BCD+1
026B:1  Forecast                                 0=Rainy, 1=Cloudy, 2=Sunny
026C:1  Tendency                                 0=Steady, 1=Rising, 2=Falling
0346:4  Indoor_Temperature [C]                   $BCD / 100.0 - 30
034B:4  Min_Indoor_Temperature [C]               $BCD / 100.0 - 30
0350:4  Max_Indoor_Temperature [C]               $BCD / 100.0 - 30
0354:10 Min_Indoor_Temperature_datetime [s]      time_convert($BCD)
035E:10 Max_Indoor_Temperature_datetime [s]      time_convert($BCD)
0369:4  Low_Alarm_Indoor_Temperature [C]         $BCD / 100.0 - 30
036E:4  High_Alarm_Indoor_Temperature [C]        $BCD / 100.0 - 30
0373:4  Outdoor_Temperature [C]                  $BCD / 100.0 - 30
0378:4  Min_Outdoor_Temperature [C]              $BCD / 100.0 - 30
037D:4  Max_Outdoor_Temperature [C]              $BCD / 100.0 - 30
0381:10 Min_Outdoor_Temperature_datetime [s]     time_convert($BCD)
038B:10 Max_Outdoor_Temperature_datetime [s]     time_convert($BCD)
0396:4  Low_Alarm_Outdoor_Temperature [C]        $BCD / 100.0 - 30
039B:4  High_Alarm_Outdoor_Temperature [C]       $BCD / 100.0 - 30
03A0:4  Windchill [C]                            $BCD / 100.0 - 30
03A5:4  Min_Windchill [C]                        $BCD / 100.0 - 30
03AA:4  Max_Windchill [C]                        $BCD / 100.0 - 30
03AE:10 Min_Windchill_datetime [s]               time_convert($BCD)
03B8:10 Max_Windchill_datetime [s]               time_convert($BCD)
03C3:4  Low_Alarm_Windchill [C]                  $BCD / 100.0 - 30
03C8:4  High_Alarm_Windchill [C]                 $BCD / 100.0 - 30
03CE:4  Dewpoint [C]                             $BCD / 100.0 - 30
03D3:4  Min_Dewpoint [C]                         $BCD / 100.0 - 30
03D8:4  Max_Dewpoint [C]                         $BCD / 100.0 - 30
03DC:10 Min_Dewpoint_datetime [s]                time_convert($BCD)
03E6:10 Max_Dewpoint_datetime [s]                time_convert($BCD)
03F1:4  Low_Alarm_Dewpoint [C]                   $BCD / 100.0 - 30
03F6:4  High_Alarm_Dewpoint [C]                  $BCD / 100.0 - 30
03FB:2  Indoor_Humidity [%]                      $BCD
03FD:2  Min_Indoor_Humidity [%]                  $BCD
03FF:2  Max_Indoor_Humidity [%]                  $BCD
0401:10 Min_Indoor_Humidity_datetime [s]         time_convert($BCD)
040B:10 Max_Indoor_Humidity_datetime [s]         time_convert($BCD)
0415:2  Low_Alarm_Indoor_Humidity [%]            $BCD
0417:2  High_Alarm_Indoor_Humidity [%]           $BCD
0419:2  Outdoor_Humidity [%]                     $BCD
041B:2  Min_Outdoor_Humidity [%]                 $BCD
041D:2  Max_Outdoor_Humidity [%]                 $BCD
041F:10 Min_Outdoor_Humidity_datetime [s]        time_convert($BCD)
0429:10 Max_Outdoor_Humidity_datetime [s]        time_convert($BCD)
0433:2  Low_Alarm_Outdoor_Humidity [%]           $BCD
0435:2  High_Alarm_Outdoor_Humidity [%]          $BCD
0497:6  Rain_24hour [mm]                         $BCD / 100.0
049D:6  Max_Rain_24hour [mm]                     $BCD / 100.0
04A3:10 Max_Rain_24hour_datetime [s]             time_convert($BCD)
04B4:6  Rain_1hour [mm]                          $BCD / 100.0
04BA:6  Max_Rain_1hour [mm]                      $BCD / 100.0
04C0:10 Max_Rain_1hour_datetime [s]              time_convert($BCD)
04D2:6  Rain_Total [mm]                          $BCD / 100.0
04D8:10 Rain_Total_datetime [s]                  time_convert($BCD)
0529:3  Wind_Speed [m/s]                         $HEX / 10.0
052C:1  Wind_Direction [degrees]                 $HEX * 22.5
054D:1  Connection_Type                          0=Cable, 3=lost, F=Wireless
054F:2  Countdown_time_to_next_datBinary [s]     $HEX / 2.0
05D8:5  Absolute_Pressure [hPa]                  $BCD / 10.0
05E2:5  Relative_Pressure [hPa]                  $BCD / 10.0
05EC:5  Pressure_Correction [hPa]                $BCD / 10.0- 1000
05F6:5  Min_Absolute_Pressure [hPa]              $BCD / 10.0
0600:5  Min_Relative_Pressure [hPa]              $BCD / 10.0
060A:5  Max_Absolute_Pressure [hPa]              $BCD / 10.0
0614:5  Max_Relative_Pressure [hPa]              $BCD / 10.0
061E:10 Min_Pressure_datetime [s]                time_convert($BCD)
0628:10 Max_Pressure_datetime [s]                time_convert($BCD)
063C:5  Low_Alarm_Pressure [hPa]                 $BCD / 10.0
0650:5  High_Alarm_Pressure [hPa]                $BCD / 10.0
END_MEMORY_MAP

# FIXME: split and parse
# FIXME: include canonical_name ?
# FIXME: POD

1;
