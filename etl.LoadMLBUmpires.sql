USE [MLB]
GO
/****** Object:  StoredProcedure [etl].[LoadMLBUmpires]    Script Date: 3/2/2021 3:58:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 

exec [etl].[LoadMLBUmpires] 
    @Filepath = 'C:\Users\chweb\Coursework\MLB\'
    ,@StgName = 'stg.MLB_Umpires'
    ,@ResetTable = 1 

*/


ALTER   PROCEDURE [etl].[LoadMLBUmpires] 
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
DECLARE  curs_folders1 CURSOR FOR
SELECT folders from [stg].[FileFolders] WHERE folders is not NULL and import_tables = 'stg.MLBPlaybyPlay'
SET @numfolders = 0
OPEN curs_folders1
FETCH NEXT FROM curs_folders1 INTO @filefolder
WHILE (@@FETCH_STATUS = 0)
BEGIN
		SET @numfolders+=1


DECLARE curs_files1 CURSOR FOR
SELECT Name FROM @files WHERE Name IS NOT NULL

DELETE FROM @files

--Pull a list of the TXT file names from the folder that they're stored in
SET @query = 'master.dbo.xp_cmdshell ''dir "' + @filepath + @filefolder + '" /b'''
INSERT @files(Name) 
EXEC (@query)


SET @numfiles =0
OPEN curs_files1
FETCH NEXT FROM curs_files1 INTO @filename
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

insert into stg.MLB_Umpires
select 
		header.gamePk
		,officials.officialType
		,official.id as official_id
		,official.fullName as official_name

from  openjson (@json)
with
(
		gamePk INT, 
		liveData nvarchar(max) as json
) as header
outer apply openjson (header.liveData)
with
(
		boxscore nvarchar(max) as json
) liveData
outer apply openjson (liveData.boxscore)
with
(
		officials nvarchar(max) as json
) boxscore
outer apply openjson (boxscore.officials)
with
(
		official nvarchar(max) as json,
		officialType varchar(100)
) officials
outer apply openjson (officials.official)
with
(
	id int,
	fullName varchar(100)
) official



PRINT 'Importing ' + @filename + ' from ' + @filefolder + ' into ' + @StgName
  
    FETCH NEXT FROM curs_files1 INTO @filename
END
  
	

CLOSE curs_files1
DEALLOCATE curs_files1

		FETCH NEXT FROM curs_folders1 INTO @filefolder

END
CLOSE curs_folders1
DEALLOCATE curs_folders1