SET NOCOUNT ON
GO

IF EXISTS
(
	SELECT	1
	FROM 	INFORMATION_SCHEMA.TABLES
	WHERE		TABLE_NAME 	= 'Numbers'
	    	AND 	TABLE_SCHEMA 	= 'dbo'
	    	AND 	TABLE_TYPE 	= 'BASE TABLE'
)
BEGIN
	DROP TABLE dbo.Numbers
END
GO

CREATE TABLE dbo.Numbers
(
	Number smallint IDENTITY(1, 1) PRIMARY KEY
)
GO

WHILE 1 = 1
BEGIN
	INSERT INTO dbo.Numbers DEFAULT VALUES
	
	IF @@IDENTITY = 8000 
	BEGIN
		BREAK
	END
END
GO