USE [MLB]
GO

/****** Object:  View [ods].[MLB_Matlab]    Script Date: 3/2/2021 3:44:26 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER view [ods].[MLB_BattedBalls] as

select 
		CASE WHEN [stand] = 'R' THEN 1 
				WHEN [stand] = 'L' THEN 0 ELSE NULL END [stand]
      ,CASE WHEN [p_throws] = 'R' THEN 1 
				WHEN [p_throws] = 'L' THEN 0 ELSE NULL END [p_throws]
      ,CASE WHEN [pitch_type] = 'Fastball' THEN 1
				WHEN [pitch_type] = 'Breaking' THEN 2
				WHEN [pitch_type] = 'Offspeed' THEN 3 
				WHEN [pitch_type] = 'Unknown' THEN 4 ELSE NULL END [pitch_type]
      ,[effective_speed]
      ,[plate_x]
      ,[plate_z]
      ,[zone]
      ,CASE WHEN [bb_type] = 'ground_ball' THEN 1
				WHEN [bb_type] = 'line_drive' THEN 2 
				WHEN [bb_type] = 'fly_ball' THEN 3
				WHEN [bb_type] = 'popup' THEN 4 ELSE NULL END [bb_type]
      ,CASE WHEN [hit_out] = 'hit' THEN 1 
				WHEN [hit_out] = 'out' THEN 0
				WHEN [hit_out] = 'error' THEN 2 ELSE NULL END [hit_out]
      ,[x_loc]
      ,[y_loc]
      ,[launch_speed]
      ,[launch_angle]
      ,CASE WHEN [if_fielding_alignment] = 'Standard' THEN 0
				WHEN [if_fielding_alignment] = 'Strategic' THEN 1
				WHEN [if_fielding_alignment] = 'Infield shift' THEN 2 ELSE NULL END [if_fielding_alignment]
      ,CASE WHEN [of_fielding_alignment] like  '%Standard%' THEN 0
				WHEN [of_fielding_alignment] like '%Strategic%' THEN 1
				WHEN [of_fielding_alignment] like '%Extreme%' THEN 2
				WHEN [of_fielding_alignment] like '%4th%' THEN 3 ELSE NULL END [of_fielding_alignment]
			,CASE WHEN [dayNight] = 'day' THEN 0 ELSE 1 END [dayNight]
      ,[temperature]
      ,CASE WHEN [turftype] = 'Grass' THEN 1 ELSE 0 END [turftype]
      ,[leftline]
      ,[leftcenter]
      ,[center]
      ,[rightcenter]
      ,[rightline]
from [ods].[MLB_HitData] 
where --game_year = 2015 and 
[hit_out] <> 'error' 

--select distinct rtrim([of_fielding_alignment]) from [ods].[MLB_HitData]  where game_year = 2015 and [of_fielding_alignment] = 'Standard  '
GO


