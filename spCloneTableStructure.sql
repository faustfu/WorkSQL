CREATE PROCEDURE [dbo].[spCloneTableStructure]
    @SourceSchema nvarchar(255),
    @SourceTable nvarchar(255),
    @DestinationSchema nvarchar(255),
    @DestinationTable nvarchar(255),
    @RecreateIfExists bit = 0
AS
BEGIN
    /*
        Clones an existing table to another table (without data)
        Optionally drops and re-creates target table
        Copies:
            * Structure
            * Primary key
            * Indexes (including ASC/DESC, included columns, filters)
            * Constraints (and unique constraints)

        DOES NOT copy:
            * Triggers
            * File groups
            * Probably a lot of other things

        Note: Assumes that you name (unique) constraints with the table name in it (in order to not duplicate constraint names)
        ---
        TODO:
        	1)AMDSERVER.imonline
    */
    SET NOCOUNT ON;

    BEGIN TRANSACTION

    --drop the table
    if EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = @DestinationSchema AND TABLE_NAME = @DestinationTable)
    BEGIN
        if @RecreateIfExists = 1
        BEGIN
            exec('DROP TABLE [' + @DestinationSchema + '].[' + @DestinationTable + ']')
        END
        ELSE
            RETURN
    END

    --create the table
    exec('SELECT TOP (0) * INTO [' + @DestinationSchema + '].[' + @DestinationTable + '] FROM [' + @SourceSchema + '].[' + @SourceTable + ']')

    DECLARE @PKSchema nvarchar(255), @PKName nvarchar(255)
    SELECT TOP 1 @PKSchema = CONSTRAINT_SCHEMA, @PKName = CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = @SourceSchema AND TABLE_NAME = @SourceTable AND CONSTRAINT_TYPE = 'PRIMARY KEY'

    --create primary key
    IF NOT @PKSchema IS NULL AND NOT @PKName IS NULL
    BEGIN
        DECLARE @PKColumns nvarchar(4000)
        SET @PKColumns = ''

        SELECT @PKColumns = @PKColumns + '[' + COLUMN_NAME + '],'
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            where TABLE_NAME = @SourceTable and TABLE_SCHEMA = @SourceSchema AND CONSTRAINT_SCHEMA = @PKSchema AND CONSTRAINT_NAME= @PKName
            ORDER BY ORDINAL_POSITION

        SET @PKColumns = LEFT(@PKColumns, LEN(@PKColumns) - 1)

        exec('ALTER TABLE [' + @DestinationSchema + '].[' + @DestinationTable + '] ADD  CONSTRAINT [PK_' + @DestinationTable + '] PRIMARY KEY CLUSTERED (' + @PKColumns + ')');
    END

    --create other indexes
    DECLARE @IndexId int, @IndexName nvarchar(255), @IsUnique bit, @IsUniqueConstraint bit, @FilterDefinition nvarchar(4000)

    DECLARE indexcursor CURSOR FOR
    SELECT index_id, name, is_unique, is_unique_constraint, filter_definition FROM sys.indexes WHERE type = 2 and object_id = object_id('[' + @SourceSchema + '].[' + @SourceTable + ']')
    OPEN indexcursor;
    FETCH NEXT FROM indexcursor INTO @IndexId, @IndexName, @IsUnique, @IsUniqueConstraint, @FilterDefinition;
    WHILE @@FETCH_STATUS = 0
       BEGIN
            DECLARE @Unique nvarchar(255)
            SET @Unique = CASE WHEN @IsUnique = 1 THEN ' UNIQUE ' ELSE '' END

            DECLARE @KeyColumns nvarchar(4000), @IncludedColumns nvarchar(4000)
            SET @KeyColumns = ''
            SET @IncludedColumns = ''

            select @KeyColumns = @KeyColumns + '[' + c.name + '] ' + CASE WHEN is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END + ',' from sys.index_columns ic
            inner join sys.columns c ON c.object_id = ic.object_id and c.column_id = ic.column_id
            where index_id = @IndexId and ic.object_id = object_id('[' + @SourceSchema + '].[' + @SourceTable + ']') and key_ordinal > 0
            order by index_column_id

            select @IncludedColumns = @IncludedColumns + '[' + c.name + '],' from sys.index_columns ic
            inner join sys.columns c ON c.object_id = ic.object_id and c.column_id = ic.column_id
            where index_id = @IndexId and ic.object_id = object_id('[' + @SourceSchema + '].[' + @SourceTable + ']') and key_ordinal = 0
            order by index_column_id

            IF LEN(@KeyColumns) > 0
                SET @KeyColumns = LEFT(@KeyColumns, LEN(@KeyColumns) - 1)

            IF LEN(@IncludedColumns) > 0
            BEGIN
                SET @IncludedColumns = ' INCLUDE (' + LEFT(@IncludedColumns, LEN(@IncludedColumns) - 1) + ')'
            END

            IF @FilterDefinition IS NULL
                SET @FilterDefinition = ''
            ELSE
                SET @FilterDefinition = 'WHERE ' + @FilterDefinition + ' '

            if @IsUniqueConstraint = 0
                exec('CREATE ' + @Unique + ' NONCLUSTERED INDEX [' + @IndexName + '] ON [' + @DestinationSchema + '].[' + @DestinationTable + '] (' + @KeyColumns + ')' + @IncludedColumns + @FilterDefinition)
            ELSE
                BEGIN
                    SET @IndexName = REPLACE(@IndexName, @SourceTable, @DestinationTable)
                    exec('ALTER TABLE [' + @DestinationSchema + '].[' + @DestinationTable + '] ADD  CONSTRAINT [' + @IndexName + '] UNIQUE NONCLUSTERED (' + @KeyColumns + ')');
                END

            FETCH NEXT FROM indexcursor INTO @IndexId, @IndexName, @IsUnique, @IsUniqueConstraint, @FilterDefinition;
       END;
    CLOSE indexcursor;
    DEALLOCATE indexcursor;

    --create constraints
    DECLARE @ConstraintName nvarchar(4000), @CheckClause nvarchar(4000)
    DECLARE constraintcursor CURSOR FOR
        SELECT REPLACE(c.CONSTRAINT_NAME, @SourceTable, @DestinationTable), CHECK_CLAUSE from INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE t
        INNER JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS c ON c.CONSTRAINT_SCHEMA = TABLE_SCHEMA AND c.CONSTRAINT_NAME = t.CONSTRAINT_NAME
         WHERE TABLE_SCHEMA = @SourceSchema AND TABLE_NAME = @SourceTable
    OPEN constraintcursor;
    FETCH NEXT FROM constraintcursor INTO @ConstraintName, @CheckClause;
    WHILE @@FETCH_STATUS = 0
       BEGIN
            exec('ALTER TABLE [' + @DestinationSchema + '].[' + @DestinationTable + '] WITH CHECK ADD  CONSTRAINT [' + @ConstraintName + '] CHECK ' + @CheckClause)
            exec('ALTER TABLE [' + @DestinationSchema + '].[' + @DestinationTable + '] CHECK CONSTRAINT [' + @ConstraintName + ']')
            FETCH NEXT FROM constraintcursor INTO @ConstraintName, @CheckClause;
       END;
    CLOSE constraintcursor;
    DEALLOCATE constraintcursor;

    COMMIT TRANSACTION
END