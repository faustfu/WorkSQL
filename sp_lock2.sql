CREATE PROC sp_lock2
(
@dbname sysname = NULL,
@spid int = NULL
)
AS
/*************************************************************************************************
		Copyright © 2001 Narayana Vyas Kondreddi. All rights reserved.
                                          
Purpose:	To display detailed lock information

Written by:	Narayana Vyas Kondreddi
		http://vyaskn.tripod.com

Tested on: 	SQL Server 7.0 and SQL Server 2000

Date modified:	August-13-2001 12:00 AM

Email: 		vyaskn@hotmail.com

Examples:

To see all the locks:
EXEC sp_lock2

To see all the locks in a particular database, say 'pubs':
EXEC sp_lock2 pubs

To see all the locks held by a particular spid, say 53:
EXEC sp_lock2 @spid = 53

To see all the locks held by a particular spid (23), in a particular database (pubs):
EXEC sp_lock2 pubs, 23
*************************************************************************************************/

BEGIN
SET NOCOUNT ON
CREATE TABLE #lock
(
	spid int,
	dbid int,
	ObjId int,
	IndId int,
	Type char(5),
	Resource char(20),
	Mode char(10),
	Status char(10)
)

INSERT INTO #lock EXEC sp_lock

IF @dbname IS NULL
BEGIN
	IF @spid IS NULL
	BEGIN
		SELECT a.spid AS SPID, 
		(SELECT DISTINCT program_name FROM master..sysprocesses WHERE spid = a.spid) AS [Program Name],
		db_name(dbid) AS [Database Name], ISNULL(object_name(ObjId),'') AS [Object Name],IndId, Type, Resource, Mode, Status
		FROM #lock a
	END
	ELSE
	BEGIN
		SELECT a.spid AS SPID, 
		(SELECT DISTINCT program_name FROM master..sysprocesses WHERE spid = a.spid) AS [Program Name],	
		db_name(dbid) AS [Database Name], ISNULL(object_name(ObjId),'') AS [Object Name],IndId, Type, Resource, Mode, Status
		FROM #lock a
		WHERE spid = @spid
	END
END
ELSE
BEGIN
	IF @spid IS NULL 
	BEGIN
		SELECT a.spid AS SPID,
		(SELECT DISTINCT program_name FROM master..sysprocesses WHERE spid = a.spid) AS [Program Name],		
		ISNULL(object_name(a.ObjId),'') AS [Object Name],a.IndId, 
		ISNULL((SELECT name FROM sysindexes WHERE id = a.objid and indid = a.indid ),'') AS [Index Name],
		a.Type, a.Resource, a.Mode, a.Status
		FROM #lock a
		WHERE dbid = db_id(@dbname)
	END
	ELSE
	BEGIN
		SELECT a.spid AS SPID,
		(SELECT DISTINCT program_name FROM master..sysprocesses WHERE spid = a.spid) AS [Program Name],
		ISNULL(object_name(a.ObjId),'') AS [Object Name],a.IndId, 
		ISNULL((SELECT name FROM sysindexes WHERE id = a.objid and indid = a.indid ),'') AS [Index Name],
		a.Type, a.Resource, a.Mode, a.Status
		FROM #lock a
		WHERE dbid = db_id(@dbname) AND spid = @spid			
	END
END

DROP TABLE #lock

END
