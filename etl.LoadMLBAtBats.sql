USE [MLB]
GO
/****** Object:  StoredProcedure [etl].[LoadMLBAtBats]    Script Date: 12/20/2020 10:06:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 

exec [etl].[LoadMLBAtBats] 
    @Filepath = 'C:\Users\chweb\Coursework\MLB\'
    ,@StgName = 'stg.MLB_AtBats'
    ,@ResetTable = 1 

*/



ALTER   PROCEDURE [etl].[LoadMLBAtBats] 
    @Filepath varchar(500)
    ,@StgName varchar(128)
    ,@ResetTable bit = 0 
		
		as


SET QUOTED_IDENTIFIER OFF
 

DECLARE @query varchar(1000)
DECLARE @numfiles int
DECLARE @numfolders int
DECLARE @filename varchar(100)
DECLARE @filefolder varchar(100)
DECLARE @files TABLE (Name varchar(200) NULL)


IF @ResetTable = 1
BEGIN
    PRINT 'Emptying table ' + @StgName + '...'
    EXEC ('DELETE ' + @StgName)
END


--Pull a list of the folders data is stored in (probably should make this dynamic)
DECLARE  curs_folders3 CURSOR FOR
SELECT folders from [stg].[FileFolders] WHERE folders is not NULL and import_tables = 'stg.MLBPlaybyPlay'
SET @numfolders = 0
OPEN curs_folders3
FETCH NEXT FROM curs_folders3 INTO @filefolder
WHILE (@@FETCH_STATUS = 0)
BEGIN
		SET @numfolders+=1


DECLARE curs_files3 CURSOR FOR
SELECT Name FROM @files WHERE Name IS NOT NULL

DELETE FROM @files

--Pull a list of the TXT file names from the folder that they're stored in
SET @query = 'master.dbo.xp_cmdshell ''dir "' + @filepath + @filefolder + '" /b'''
INSERT @files(Name) 
EXEC (@query)


SET @numfiles =0
OPEN curs_files3
FETCH NEXT FROM curs_files3 INTO @filename
WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @numfiles+=1



declare @stm nvarchar(max)
declare @json nvarchar(max)


--declare @Filepath varchar(100) = 'C:\Users\chweb\Coursework\MLB\'
--DECLARE @filefolder varchar(100) = 'json'
--declare @filename varchar(100) = '413649.json'


SET @stm = N'
        SELECT @json = BulkColumn 
        FROM OPENROWSET (BULK ''' + @Filepath + @filefolder + '\' + @filename + ''', SINGLE_CLOB) AS j
    '
    EXEC sp_executesql @stm, N'@json AS VARCHAR(MAX) OUTPUT', @json OUTPUT




insert into stg.MLB_AtBats 

select 
		header.gamePk
		,result.type 
    ,result.event 
    ,result.eventType 
    ,result.description 
    ,result.rbi 
    ,result.awayScore 
    ,result.homeScore 
		,allPlays.pitchIndex  -- array like [0, 1, 2]; will select max(pitchindex) from pitch data to tie pitches to outcomes
		,about.atBatIndex
    ,about.halfInning 
    ,about.inning 
    ,about.hasOut 
    ,about.captivatingIndex 
		,count.balls 
		,count.strikes 
		,count.outs 
		,batter.id as batter_id
	  ,batter.fullName as batter_name
		,pitcher.id as pitcher_id
	  ,pitcher.fullName as pitcher_name
		,postOnFirst.id as runnerid_onfirst
		,postOnSecond.id as runnerid_onsecond
		,postOnThird.id as runnerid_onthird
		--,movement.[start] 
  --  ,movement.[end]
  --  ,movement.outBase 
  --  ,movement.isOut 
  --  ,movement.outNumber 
		--,details.[event] 
  --  ,details.eventType 
  --  ,details.movementReason 
  --  ,details.playIndex
		--,runner.id as runner_id
		--,credits.credit
		--,player.id as player_id
		--,position.code as position_code
		--,position.[name] as position_name
		--,position.[type] as position_type
		--,position.abbreviation

--into stg.MLB_AtBats
from  openjson (@json)
with
(
		gamePk INT, 
		liveData nvarchar(max) as json
) as header
OUTER APPLY openjson (header.liveData)
with
(
		plays nvarchar(max) as json
) as liveData
OUTER APPLY openjson (liveData.plays)
with
(
		allPlays nvarchar(max) as json
) as plays
OUTER APPLY openjson (plays.allPlays)
with
(
		result nvarchar(max) as json,
		about nvarchar(max) as json,
		[count] nvarchar(max) as json,
		matchup nvarchar(max) as json,
		runners nvarchar(max) as json,
		pitchIndex nvarchar(100)
) as allPlays
OUTER APPLY openjson (allPlays.result)
with
(
		      type varchar(100),
          event varchar(100),
          eventType varchar(100),
          description varchar(200),
          rbi INT,
          awayScore INT,
          homeScore INT
) as result
OUTER APPLY openjson (allPlays.about)
with
(
		      atBatIndex INT,
          halfInning varchar(10),
          inning INT,
          hasOut varchar(10),
          captivatingIndex INT
) as about
OUTER APPLY openjson (allPlays.count)
with
(
		balls INT,
		strikes INT,
		outs INT
) as count
OUTER APPLY openjson (allPlays.matchup)
with
(
		batter nvarchar(max) as json,
		pitcher nvarchar(max) as json,
		postOnFirst nvarchar(max) as json,
		postOnSecond nvarchar(max) as json,
		postOnThird nvarchar(max) as json
) as matchup
OUTER APPLY openjson (matchup.batter)
with
(
	id INT,
	fullName varchar(100)
) as batter
OUTER APPLY openjson (matchup.pitcher)
with
(
	id INT,
	fullName varchar(100)
) as pitcher
OUTER APPLY openjson (matchup.postOnFirst)
with
(
	id INT
) as postOnFirst
OUTER APPLY openjson (matchup.postOnSecond)
with
(
	id INT
) as postOnSecond
OUTER APPLY openjson (matchup.postOnThird)
with
(
	id INT
) as postOnThird
--OUTER APPLY openjson (currentPlay.runners)
--with
--(
-- movement nvarchar(max) as json,
-- details nvarchar(max) as json,
-- credits nvarchar(max) as json
--) as runners
--OUTER APPLY openjson (runners.movement)
--with
--(
--     [start] varchar(100),
--     [end] varchar(100),
--     outBase varchar(100),
--     isOut varchar(10),
--     outNumber INT
--) as movement
--OUTER APPLY openjson (runners.details)
--with
--(
--		   [event] varchar(100),
--       eventType varchar(100),
--       movementReason varchar(100),
--			 runner nvarchar(max) as json,
--       playIndex INT
--) as details
--OUTER APPLY openjson (details.runner)
--with
--(
--		id INT
--) as runner
--OUTER APPLY openjson (runners.credits)
--with
--(
--		player nvarchar(max) as json,
--		position nvarchar(max) as json,
--		credit varchar(100)
--) as credits
--OUTER APPLY openjson (credits.player)
--with
--(
--		id INT
--) as player
--OUTER APPLY openjson (credits.position)
--with
--(
--		code INT,
--		name varchar(100),
--		type varchar(100),
--		abbreviation varchar(10)
--) as position




PRINT 'Importing ' + @filename + ' from ' + @filefolder + ' into ' + @StgName
  
    FETCH NEXT FROM curs_files3 INTO @filename
END
  
	

CLOSE curs_files3
DEALLOCATE curs_files3

		FETCH NEXT FROM curs_folders3 INTO @filefolder

END
CLOSE curs_folders3
DEALLOCATE curs_folders3


update a
set pitchindex = b.pitchindex
from stg.mlb_atbats a
		INNER JOIN (
select max([index]) pitchindex
		,gamepk
		,atbatindex
from stg.mlb_pitches
group by gamepk, atbatindex
) b ON
a.gamepk = b.gamepk AND a.atbatindex = b.atbatindex
