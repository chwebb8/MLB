USE [MLB]
GO

/****** Object:  View [ods].[MLB_AllHits]    Script Date: 12/20/2020 5:23:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER VIEW [ods].[MLB_AllHits] as 



select 
		/* GAME INFO */
		p.GamePk, 
		COALESCE(sc.game_year,YEAR(g.[datetime])) as GameYear,
		sc.inning_topbot  as HalfInning, 

		/* PITCH INFO */
		p.pitchhand_code as PitchhandCode,
		p.StartSpeed as PitchSpeed,
		p.Pitch_Description as PitchDescription,
		

		/* HIT INFO */
		p.batside_code  as BatsideCode,
		sc.bb_type as BBType,
		sc.hit_location as HitLocation,
		sc.launch_angle as LaunchAngle,
		sc.launch_speed as LaunchSpeed,
		ROUND(57.296 * atan((hc_x-125.42) / (NULLIF(198.27-hc_y,0))),1) as SprayAngle,
		ROUND(2.495671 * (hc_x - 125),1) as Xloc,
		ROUND(2.495671 * (199 - hc_y),1) as Yloc,

		[events] as PlayEvent,
		[des] as PlayDescription,
		
		/* VENUE */
		v.LeftLine,
		v.LeftCenter,
		v.Center,
		v.RightCenter,
		v.RightLine,

		/* FIELDING */
		sc.fielder_7 as LeftFielder,
		sc.fielder_8 as CenterFielder,
		sc.fielder_9 as RightFielder

	

from stg.mlb_pitches p left outer join 
		stg.mlb_atbats ab ON p.gamepk = ab.gamepk AND p.atbatindex = ab.atbatindex and p.[index] = ab.pitchindex left outer join 
		ods.mlb_statcast sc ON p.gamepk = sc.game_pk AND p.pitchnumber = sc.pitch_number AND (p.AtBatIndex + 1) = sc.at_bat_number left outer join  
		stg.mlb_games g ON p.gamepk = g.gamepk LEFT OUTER JOIN 
		stg.mlb_venues v on g.venue_id = v.venue_id
where p.play_type = 'pitch'
		and p.isinplay = 'True'
		


GO


