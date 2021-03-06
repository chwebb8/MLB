USE [MLB]
GO
/****** Object:  StoredProcedure [etl].[LoadMLBVenues]    Script Date: 3/2/2021 3:58:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 

exec [etl].[LoadMLBVenues] 
    @Filepath = 'C:\Users\chweb\Coursework\MLB\'
    ,@StgName = 'stg.MLB_Venues'
    ,@ResetTable = 1 

*/



ALTER   PROCEDURE [etl].[LoadMLBVenues] 
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
DECLARE  curs_folders4 CURSOR FOR
SELECT folders from [stg].[FileFolders] WHERE folders is not NULL and import_tables = 'stg.MLBPlaybyPlay'
SET @numfolders = 0
OPEN curs_folders4
FETCH NEXT FROM curs_folders4 INTO @filefolder
WHILE (@@FETCH_STATUS = 0)
BEGIN
		SET @numfolders+=1


DECLARE curs_files4 CURSOR FOR
SELECT Name FROM @files WHERE Name IS NOT NULL

DELETE FROM @files

--Pull a list of the TXT file names from the folder that they're stored in
SET @query = 'master.dbo.xp_cmdshell ''dir "' + @filepath + @filefolder + '" /b'''
INSERT @files(Name) 
EXEC (@query)


SET @numfiles =0
OPEN curs_files4
FETCH NEXT FROM curs_files4 INTO @filename
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




insert into stg.MLB_Venues

select venue.id as venue_id
		,venue.name as venue_name
		,location.city as city
		,location.state as state
    ,latitude 
    ,longitude 
		,fieldInfo.capacity 
    ,fieldInfo.turfType 
    ,fieldInfo.roofType 
    ,fieldInfo.leftLine 
    ,fieldInfo.leftCenter 
    ,fieldInfo.center 
    ,fieldInfo.rightCenter
    ,fieldInfo.rightLine 


from  openjson (@json)
with
(
		gameData nvarchar(max) as json
) as header
outer apply openjson (header.gameData)
with
(
		venue nvarchar(max) as json
) gameData
outer apply openjson (gameData.venue)
with
(
		id INT,
		name varchar(100),
		location nvarchar(max) as json,
--		timeZone nvarchar(max) as json,
		fieldInfo nvarchar(max) as json
) venue
outer apply openjson (venue.location)
with
(
		city varchar(100),
		state varchar(100),
		defaultCoordinates nvarchar(max) as json
) location
outer apply openjson (venue.fieldInfo)
with
(
    capacity int,
    turfType varchar(100),
    roofType varchar(100),
    leftLine int,
    leftCenter int,
    center int,
    rightCenter int,
    rightLine int
) fieldInfo
outer apply openjson (location.defaultCoordinates)
with
(
     latitude float,
     longitude float
) defaultCoordinates


WHERE NOT EXISTS 
(SELECT * FROM stg.MLB_Venues a WHERE a.venue_id = venue.id)


PRINT 'Importing ' + @filename + ' from ' + @filefolder + ' into ' + @StgName
  
    FETCH NEXT FROM curs_files4 INTO @filename
END
  
	

CLOSE curs_files4
DEALLOCATE curs_files4

		FETCH NEXT FROM curs_folders4 INTO @filefolder

END
CLOSE curs_folders4
DEALLOCATE curs_folders4