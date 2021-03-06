USE [MLB]
GO
/****** Object:  StoredProcedure [etl].[LoadMLBPlayers]    Script Date: 3/2/2021 3:57:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*

exec [etl].[LoadMLBPlayers] 
    @Filepath = 'C:\Users\chweb\Coursework\MLB\'
    ,@StgName = 'stg.MLB_Players'
    ,@ResetTable = 1 

*/



ALTER   PROCEDURE [etl].[LoadMLBPlayers] 
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
SELECT folders from [stg].[FileFolders] WHERE folders is not NULL and import_tables = 'stg.Players'
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
--DECLARE @filefolder varchar(100) = 'Players'
--declare @filename varchar(100) = '112526.json'


SET @stm = N'
        SELECT @json = BulkColumn 
        FROM OPENROWSET (BULK ''' + @Filepath + @filefolder + '\' + @filename + ''', SINGLE_CLOB) AS j
    '
    EXEC sp_executesql @stm, N'@json AS VARCHAR(MAX) OUTPUT', @json OUTPUT




insert into stg.MLB_Players

select 

		people.id as player_id
    ,people.fullName 
    ,people.firstName
    ,people.lastName
    ,people.primaryNumber 
    ,people.birthDate 
    ,people.birthCity 
    ,people.birthCountry 
    ,people.height
    ,people.[weight]
		,people.useName
    ,people.boxscoreName 
    ,people.nickName 
    ,people.pronunciation 
    ,people.mlbDebutDate 
    ,people.strikeZoneTop 
    ,people.strikeZoneBottom 
		,primaryPosition.[code] as position_code
    ,primaryPosition.[name] as position_name
    ,primaryPosition.[type] as position_type
    ,primaryPosition.abbreviation as position_abbreviation
		,batSide.code as batside_code
    ,batSide.[description] as batside_description
		,batSide.code as pitchhand_code
    ,batSide.[description] as pitchhand_description
			
--into stg.MLB_Players
from  openjson (@json)
with
(
		people nvarchar(max) as json
) as header
OUTER APPLY openjson (header.people)
with 
(
		id INT,
    fullName varchar(100),
    firstName varchar(100),
    lastName varchar(100),
    primaryNumber INT,
    birthDate date,
    birthCity varchar(100),
    birthCountry varchar(100),
    height varchar(10),
    weight INT,
		useName varchar(100),
    boxscoreName varchar(100),
    nickName varchar(100),
    pronunciation varchar(100),
    mlbDebutDate date,
    strikeZoneTop float,
    strikeZoneBottom float,
		primaryPosition nvarchar(max) as json,
		batSide nvarchar(max) as json,
		pitchHand nvarchar(max) as json
) as people
OUTER APPLY openjson (people.primaryPosition)
with 
(
      [code] varchar(10),
      [name] varchar(20),
      [type] varchar(20),
      abbreviation varchar(10)
) primaryPosition
OUTER APPLY openjson (people.batSide)
with 
(
      code varchar(10),
      [description] varchar(10)
) batSide
OUTER APPLY openjson (people.pitchHand)
with 
(
      code varchar(10),
      [description] varchar(10)
) pitchHand


PRINT 'Importing ' + @filename + ' from ' + @filefolder + ' into ' + @StgName
  
    FETCH NEXT FROM curs_files INTO @filename
END
  
	

CLOSE curs_files
DEALLOCATE curs_files

		FETCH NEXT FROM curs_folders INTO @filefolder

END
CLOSE curs_folders
DEALLOCATE curs_folders