USE [MLB]
GO
/****** Object:  StoredProcedure [etl].[LoadMLBGames]    Script Date: 3/2/2021 3:57:14 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 

exec [etl].[LoadMLBGames] 
    @Filepath = 'C:\Users\chweb\Coursework\MLB\'
    ,@StgName = 'stg.MLB_Games'
    ,@ResetTable = 1 

*/



ALTER   PROCEDURE [etl].[LoadMLBGames] 
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
DECLARE  curs_folders2 CURSOR FOR
SELECT folders from [stg].[FileFolders] WHERE folders is not NULL and import_tables = 'stg.MLBPlaybyPlay'
SET @numfolders = 0
OPEN curs_folders2
FETCH NEXT FROM curs_folders2 INTO @filefolder
WHILE (@@FETCH_STATUS = 0)
BEGIN
		SET @numfolders+=1


DECLARE curs_files2 CURSOR FOR
SELECT Name FROM @files WHERE Name IS NOT NULL

DELETE FROM @files

--Pull a list of the TXT file names from the folder that they're stored in
SET @query = 'master.dbo.xp_cmdshell ''dir "' + @filepath + @filefolder + '" /b'''
INSERT @files(Name) 
EXEC (@query)


SET @numfiles =0
OPEN curs_files2
FETCH NEXT FROM curs_files2 INTO @filename
WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @numfiles+=1



declare @stm nvarchar(max)
declare @json nvarchar(max)


--declare @Filepath varchar(100) = 'C:\Users\chweb\Coursework\MLB\'
--DECLARE @filefolder varchar(100) = 'json'
--declare @filename varchar(100) = '570335.json'


SET @stm = N'
        SELECT @json = BulkColumn 
        FROM OPENROWSET (BULK ''' + @Filepath + @filefolder + '\' + @filename + ''', SINGLE_CLOB) AS j
    '
    EXEC sp_executesql @stm, N'@json AS VARCHAR(MAX) OUTPUT', @json OUTPUT




insert into stg.MLB_Games

select 
		header.gamePk
		,game.type 
		,game.doubleHeader 
		,game.id as game_id
		,game.gamedayType 
		,game.tiebreaker 
		,game.gameNumber
		,game.season 
		,[datetime].[dateTime]
    ,[datetime].originalDate
    ,[datetime].dayNight
    ,CONVERT(varchar,[datetime].[time],8) [time]
    ,[datetime].[ampm]

		,lineScore.currentInning as innings
		,weather.condition as weather
		,weather.temp as temperature
		,weather.wind
		,venue.id as venue_id
		,venue.name as venue_name
		,away.id as away_id
		,away.name as away_name

		,away_score.runs as away_runs
		,away_score.hits as away_hits
		,away_score.errors as away_errors
		,away_score.leftOnBase as away_leftonbase

		,away_record.wins as away_wins
		,away_record.losses as away_losses
		,away_record.winningPercentage as away_pct
		,home.id as home_id
		,home.name as home_name

		,home_score.runs as home_runs
		,home_score.hits as home_hits
		,home_score.errors as home_errors
		,home_score.leftOnBase as home_leftonbase

		,home_record.wins as home_wins
		,home_record.losses as home_losses
		,home_record.winningPercentage as home_pct
		--,officials.officialType

from  openjson (@json)
with
(
		gamePk INT, 
		gameData nvarchar(max) as json,
		liveData nvarchar(max) as json
) as header
outer apply openjson (header.gameData)
with
(
		game nvarchar(max) as json,
		datetime nvarchar(max) as json,
		teams nvarchar(max) as json,
		venue nvarchar(max) as json,
		weather nvarchar(max) as json
) as gameData
outer apply openjson (gameData.game)
with
(
		type varchar(10),
		doubleHeader varchar(10),
		id varchar(100),
		gamedayType varchar(10),
		tiebreaker varchar(10),
		gameNumber int,
		season int
) as game
outer apply openjson (gameData.datetime)
with
(
		[dateTime] datetime,
    originalDate date,
    dayNight varchar(10),
    [time] time,
    [ampm] varchar(5)
) datetime
outer apply openjson (gameData.teams)
with
(
		away nvarchar(max) as json,
		home nvarchar(max) as json
) teams
outer apply openjson (teams.away)
with
(
		id int,
		name varchar(50),
		record nvarchar(max) as json
) away
outer apply openjson (away.record)
with
(
		wins int,
		losses int,
		winningPercentage float
) away_record
outer apply openjson (teams.home)
with
(
		id int,
		name varchar(50),
		record nvarchar(max) as json
) home
outer apply openjson (home.record)
with
(
		wins int,
		losses int,
		winningPercentage float
) home_record
outer apply openjson (gameData.venue)
with
(
		id int,
		name varchar(100)
) venue
outer apply openjson (gameData.weather)
with
(
		condition varchar(100),
		temp int,
		wind varchar(100)
) weather
outer apply openjson (header.liveData)
with
(
		linescore nvarchar(max) as json
) liveData
outer apply openjson (liveData.linescore)
with
(
		teams nvarchar(max) as json
		,currentInning INT
) linescore
outer apply openjson (linescore.teams)
with
(
		home nvarchar(max) as json,
		away nvarchar(max) as json
) ls_teams
outer apply openjson (ls_teams.away)
with
(
		runs INT,
		hits INT,
		errors INT,
		leftOnBase INT
) away_score
outer apply openjson (ls_teams.home)
with
(
		runs INT,
		hits INT,
		errors INT,
		leftOnBase INT
) home_score



PRINT 'Importing ' + @filename + ' from ' + @filefolder + ' into ' + @StgName
  
    FETCH NEXT FROM curs_files2 INTO @filename
END
  
	

CLOSE curs_files2
DEALLOCATE curs_files2

		FETCH NEXT FROM curs_folders2 INTO @filefolder

END
CLOSE curs_folders2
DEALLOCATE curs_folders2