---
IF OBJECT_ID('debug_log_01') IS NOT NULL
    DROP TABLE debug_log_01
GO
CREATE TABLE debug_log_01(
Id INT IDENTITY(1,1),
SysDateTime DATETIME NOT NULL DEFAULT GETDATE(),
LogContent NTEXT
)
GO
ALTER TABLE debug_log_01 ADD CONSTRAINT PK_DEBUG_LOG_01 PRIMARY KEY (Id)
GO