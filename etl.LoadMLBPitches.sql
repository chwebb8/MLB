USE [MLB]
GO

/****** Object:  StoredProcedure [etl].[LoadMLBPitches]    Script Date: 12/20/2020 10:03:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* 

exec [etl].[LoadMLBPitches] 
    @Filepath = 'C:\Users\chweb\Coursework\MLB\'
    ,@StgName = 'stg.MLB_Pitches'
    ,@ResetTable = 1 

*/


ALTER   PROCEDURE [etl].[LoadMLBPitches] 
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
DECLARE  curs_folders CURSOR FOR
SELECT folders from [stg].[FileFolders] WHERE folders is not NULL and import_tables = 'stg.MLBPlaybyPlay'
SET @numfolders = 0
OPEN curs_folders
FETCH NEXT FROM curs_folders INTO @filefolder
WHILE (@@FETCH_STATUS = 0)
BEGIN
		SET @numfolders+=1


DECLARE curs_files CURSOR FOR
SELECT Name FROM @files WHERE Name IS NOT NULL

DELETE FROM @files

--Pull a list of the TXT file names from the folder that they're stored in
SET @query = 'master.dbo.xp_cmdshell ''dir "' + @filepath + @filefolder + '" /b'''
INSERT @files(Name) 
EXEC (@query)


SET @numfiles =0
OPEN curs_files
FETCH NEXT FROM curs_files INTO @filename
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



insert into stg.MLB_Pitches
select 
		header.gamePk
		,allplays.AtBatIndex
		,playevents.[index]
		,playevents.pfxId
		,playevents.playId
		,batter.id as batter_id
		,batter.fullName as batter_name
		,batSide.code as batside_code
		,batSide.description as batside_description
		,pitcher.id as pitcher_id
		,pitcher.fullName as pitcher_name
		,pitchHand.code as pitchhand_code
		,pitchHand.description as pitchhand_description
		--,splits.batter as splits_batter
		--,splits.pitcher as splits_pitcher
		--,splits.menOnBase as splits_menOnBase   is this correct?
		,playevents.pitchNumber 
		,[count].balls
		,[count].strikes
		,playevents.[type] as play_type
		,details.[description] as play_description
		,details.code as play_code
		,details.isInPlay
		,type.code as pitch_code
		,type.[description] as pitch_description
		,pitchData.startSpeed
    ,pitchData.endSpeed
    ,pitchData.nastyFactor
    ,pitchData.strikeZoneTop
    ,pitchData.strikeZoneBottom
    ,pitchData.[zone]
    ,pitchData.typeConfidence
    ,pitchData.plateTime
    ,pitchData.extension
		,coordinates.aY 
		,coordinates.aZ 
		,coordinates.pfxX
		,coordinates.pfxZ
		,coordinates.pX 
		,coordinates.pZ 
		,coordinates.vX0
		,coordinates.vY0
		,coordinates.vZ0
    ,coordinates.x
    ,coordinates.y 
    ,coordinates.x0 
    ,coordinates.y0 
    ,coordinates.z0 
    ,coordinates.aX 
		,breaks.breakAngle
    ,breaks.breakLength
    ,breaks.breakY
    ,breaks.spinRate
    ,breaks.spinDirection

--into stg.MLB_Pitches
from  openjson (@json)
with
(
		gamePk INT, 
		liveData nvarchar(max) as json
) as header
outer apply openjson (header.liveData)
with
(
		plays nvarchar(max) as json
) as liveData
outer apply openjson (liveData.plays)
with
(
		allPlays nvarchar(max) as json
) as plays
outer apply openjson (plays.allPlays)
with
(
--		result nvarchar(max) as json,
--		about nvarchar(max) as json,
		matchup nvarchar(max) as json,
--		runners nvarchar(max) as json,
--		[count] nvarchar(max) as json,
		playEvents nvarchar(max) as json,
		atBatIndex int
) as allPlays
outer apply openjson (allPlays.playEvents)
with
(
		details nvarchar(max) as json,
		[count] nvarchar(max) as json,
		pitchData nvarchar(max) as json,
		[index] int,
		pfxId varchar(100),
		playId varchar(100),
		pitchNumber int,
		[type] varchar(100)

) as playevents
outer apply openjson (playEvents.details)
with
(
		[description] varchar(100),
		code varchar(10),
		isInPlay varchar(10),
		[type] nvarchar(max) as json
) details
outer apply openjson (playEvents.[count])
with
(
		balls int,
		strikes int

) as [count]
outer apply openjson (details.type)
with
(
		code varchar(10),
		description varchar(100)
) type
outer apply openjson (allPlays.matchup)
with
(
		batter nvarchar(max) as json,
		batSide nvarchar(max) as json,
		pitcher nvarchar(max) as json,
		pitchHand nvarchar(max) as json--,
--		splits nvarchar(max) as json
) matchup
outer apply openjson (matchup.batter)
with
(
		id INT
		,fullName varchar(100)
) batter
outer apply openjson (matchup.batSide)
with
(
		code varchar(10)
		,description varchar(100)
) batSide
outer apply openjson (matchup.pitchHand)
with
(
		code varchar(10)
		,description varchar(100)
) pitchHand
outer apply openjson (matchup.pitcher)
with
(
		id INT
		,fullName varchar(100)
) pitcher
--outer apply openjson (matchup.splits)
--with
--(
--		batter varchar(100)
--		,pitcher varchar(100)
--		,menOnBase varchar(100)
--) splits
outer apply openjson (playEvents.pitchData)
with
(
         startSpeed float,
         endSpeed float,
         nastyFactor float,
         strikeZoneTop float,
         strikeZoneBottom float,
         coordinates nvarchar(max) as json,
         breaks nvarchar(max) as json,
         [zone] int,
         typeConfidence float,
         plateTime float,
         extension float
) pitchData
outer apply openjson (pitchData.coordinates)
with
(
        aY float,
				aZ float,
				pfxX float,
				pfxZ float,
				pX float,
				pZ float,
				vX0 float,
				vY0 float,
				vZ0 float,
        x float,
        y float,
        x0 float,
        y0 float,
        z0 float,
        aX float
) coordinates
outer apply openjson (pitchData.breaks)
with
(
				breakAngle float,
        breakLength float,
        breakY float,
        spinRate int,
        spinDirection int
	) breaks


	PRINT 'Importing ' + @filename + ' from ' + @filefolder + ' into ' + @StgName
  
    FETCH NEXT FROM curs_files INTO @filename
END
  
	

CLOSE curs_files
DEALLOCATE curs_files

		FETCH NEXT FROM curs_folders INTO @filefolder

END
CLOSE curs_folders
DEALLOCATE curs_folders
GO


