if object_id('fn_faust_get_REPSCH') is not null
    drop function fn_faust_get_REPSCH
go
create  function fn_faust_get_REPSCH
(
	@LoanID varchar(12)
)
returns @RtnValue table
(
	Id			smallint,	---����
	Date		datetime,		---������
	Capital		numeric(28,8),		---��
	Interest	numeric(18,8),		---��
	Total		numeric(28,8),		---�M
	Remark		varchar(1000)		---�Ƶ�
)
as
begin
	declare @Capital numeric(28,8),@Capital0 numeric(28,8),@IRate numeric(18,8),@Interest numeric(18,8),
	        @SDay datetime, @EDay datetime,@RCapital numeric(28,8),@SCapital numeric(28,8),
	        @DCapital numeric(28,8),@DCapital_total numeric(28,8),@DCapital_Diff numeric(28,8),
	        @TDayStr varchar(10),@ICapital numeric(28,8),@IType smallint,@Id smallint,@CType tinyint,
	        @CId smallint, @Cid_max smallint,@Cnt int;
	---���ڸ��
	declare @TAK table(
		Id			int identity(1,1),
		Capital		numeric(28,8),	---����
		Expense		numeric(28,8),	---�O��
		ADay		datetime,		---�J�b��
		SDay		datetime,		---�p���_��
		EDay		datetime,		---�p������
		Period		int,			---�p���϶�(��/��)
		Interest	numeric(18,8)	---���p�Q��
	);
	---���ڸ��
	declare @REP table(
		Id			int identity(1,1)		,
		CType		int not null			,
		�ٴڴ���	smallint not null		,
		�ٴڤ�		varchar(10) not null	,
		��ڧQ�v	numeric(18,8) not null	,
		�T�w�٥�	numeric(28,8) not null	,
		Interest	numeric(18,8) not null	,
		���p�٥�	numeric(28,8) not null
	);
	---���y���G
	declare @CashFlow table(
		Id			smallint,	---����
		Date		datetime,		---������
		Capital		numeric(28,8),		---��
		Interest	numeric(18,8),		---��
		Total		numeric(28,8),		---�M
		Remark		varchar(1000)		---�Ƶ�
	);
	---iteration=0
	select @SDay = convert(datetime, dbo.so_CDToWD(�������ڤ�)),
	       @IType = ����p��, ---1:����p��, 2:����p��
	       @SCapital = �֭p���ڪ��B
      from NAMAS
     where �U�ڱb�� = @LoanID;
	---���ڥ������(�@or�h��)
	insert into @TAK
	select abs(����) as Capital, abs(���ڤ���O) as Expense,
	       convert(datetime, dbo.so_CDToWD(�����)) as ADay,
	       convert(datetime, dbo.so_CDToWD(�_����)) as SDay,
	       null as EDay, 0 as Period, 0 as Interest
	  from NADET
	 where ����O = 'TAK' and �U�ڱb�� = @LoanID;
	---�[�p���ڶO��
	update t
       set t.Expense = t.Expense + isnull((select sum(n.���B)
                                             from NADET n
                                            where n.����O = 'EXP'
                                              and n.�U�ڱb�� = @LoanID
                                              and convert(datetime, dbo.so_CDToWD(n.�����)) = t.ADay), 0)
      from @TAK t;
	---�[�p�������ڶO��
	update t
       set t.Expense = t.Expense + isnull((select sum(n.���B)
                                             from NADET n
                                            where n.����O = 'EXP'
                                              and n.�U�ڱb�� = @LoanID
                                              and convert(datetime, dbo.so_CDToWD(n.�����)) < @SDay), 0)
      from @TAK t
     where t.ADay = @SDay;
	---�g�J��ڼ��ڸ�Ʀܲ{���y��
	insert into @CashFlow (Id, Date, Capital, Interest, Total)
	select 0,ADay,-1*(Capital - Expense),0,-1*(Capital - Expense)
	  from @TAK;
	--�g�J���p���ڤι�ڦ��ڦܦ��ڪ�
	insert into @REP
	select * from (
	---���p���ڸ��
	select 1 as CType, s.�ٴڴ���, s.�ٴڤ�, s.��ڧQ�v, s.�T�w�٥�, 0 as Interest, s.�T�w�٥� as ���p�٥�
      from NAREPSCH s
     where s.�U�ڱb�� = @LoanID
       and not exists (select 1 from NADET d where d.����O = 'REP' and d.�U�ڱb�� = @LoanID and d.�ٴڴ��� = s.�ٴڴ���)
     union
	---��ڦ��ڸ��
	select 2 as CType, n.�ٴڴ���, n.�J�b�� as �ٴڤ�, n.��ڧQ�v, n.���� as �T�w�٥�, n.�Q�� as Interest, isnull(s.�T�w�٥�,0) as ���p�٥�
	  from NADET n
	  left outer join NAREPSCH s on n.�U�ڱb�� = s.�U�ڱb�� and n.�ٴڴ��� = s.�ٴڴ���
	 where n.����O = 'REP' and n.�U�ڱb�� = @LoanID
	              ) m order by m.�ٴڤ� asc;
	---�w�ﴣ�e�ٴڪ��p�A�վ��٥����B
	select @RCapital = 0, @DCapital_total = 0, @DCapital_diff = 0;
	declare MainCur cursor FAST_FORWARD for
	select CType,Id,�T�w�٥�,���p�٥� from @REP;
	open MainCur;
	fetch next from MainCur into @CType,@Id, @ICapital, @DCapital;
	while @@fetch_status = 0
	begin
		---
		select @RCapital = @RCapital + @ICapital, @DCapital_total = @DCapital_total + @DCapital;
		select @DCapital_Diff = @RCapital - @DCapital_total;
		---�ֿn�t�B>0 => �w�w�I => ���������٥���, �t�B<0 => �O�� => �[�������٥���(todo)
		if (@CType = 1)
		begin
			if @DCapital_Diff <> 0
			begin
				if @DCapital_Diff >= @ICapital
				begin
					select @RCapital = @RCapital - @ICapital, @ICapital = 0; ---�w�I�W�L�������I�٥��� => ���������٥�
				end
				else
				begin
					select @RCapital = @RCapital - @DCapital_Diff, @ICapital = @ICapital - @DCapital_Diff; ---�w�I���W�L�������I�٥��� => �վ㥻�����I�٥���
				end
				---�^�g�վ�᥻�����٥���
				update r
				   set r.�T�w�٥� = @ICapital
				  from @REP r
				 where r.Id = @Id;
			end
		end
		---
		fetch next from MainCur into @CType,@Id, @ICapital, @DCapital;
	end
	close MainCur; deallocate MainCur;
	
	---iteration=1~n
	select @RCapital = 0, @DCapital_total = 0; ---�k�s����٥��[�`�P���p�٥��[�`
	declare MainCur cursor FAST_FORWARD for
	select CType,�ٴڴ���,�ٴڤ�,��ڧQ�v,�T�w�٥�,Interest from @REP;
	open MainCur;
	fetch next from MainCur into @CType,@Id, @TDayStr, @IRate, @ICapital, @Interest;
	while @@fetch_status = 0
	begin
		select @EDay = convert(datetime,dbo.so_CDToWD(@TDayStr));
		---��s�C�����ڭp���_����A�ñN�p���϶������p���k�s
		update t
		   set t.SDay = @SDay, t.EDay = @EDay, t.Period = 0, t.Interest = 0
		  from @TAK t;
		---
		if @CType = 1
		begin
			---�p��p���϶��Ϊ��B
			if @IType = 1 ---0:by month, 1:by day
			begin
				---by day
				update t
	               set t.Period = case
	                                   when t.ADay > t.SDay then datediff(day, t.ADay, t.EDay)
	                                   else datediff(day, t.SDay, t.EDay)
	                              end
	              from @TAK t
	             where t.ADay < t.EDay; ---�u�p�⸨�J�p���d����
				update t
				   set t.Interest = round((t.Capital)*@IRate*t.Period/100/365,0) ---�H365�ѭp���Q�v
				  from @TAK t
				 where t.Period > 0;
			end
			else
			begin
				---by month
				update t
				   set t.Period = datediff(month,t.SDay,t.EDay)
				  from @TAK t
				 where t.ADay < t.EDay ---�u�p�⸨�J�p���d����
				   and t.ADay <= t.SDay;
				update t
				   set t.Interest = round((t.Capital)*@IRate*t.Period/100/12,0) ---�H��Q�v�p��
				  from @TAK t
				 where t.Period > 0
				   and t.ADay <= t.SDay;
				---�����@�Ӥ�A�h�}��p��
				update t
	               set t.Period = datediff(day, t.ADay, t.EDay)
	              from @TAK t
	             where t.ADay < t.EDay ---�u�p�⸨�J�p���d����
	               and t.ADay > t.SDay;
				update t
				   set t.Interest = round((t.Capital)*@IRate*t.Period/100/365,0) ---�H365�ѭp���Q�v
				  from @TAK t
				 where t.Period > 0
				   and t.ADay > t.SDay;
			end
			---�g�J���p���ڸ�Ʀܲ{���y��
			insert into @CashFlow (Id, Date, Capital, Interest, Total)
			select @Id,@EDay,@ICapital,isnull(sum(Interest),0),@ICapital+isnull(sum(Interest),0)
			  from @TAK
			 where Interest > 0;
		end
		else
		begin
			---�g�J��ڦ��ڸ�Ʀܲ{���y��
			insert into @CashFlow (Id, Date, Capital, Interest, Total)
			values (@Id,@EDay,@ICapital,@Interest,@ICapital+@Interest);
		end
		---��s�U���p���_����`�٥����B
		select @SDay = @EDay, @RCapital = @RCapital + @ICapital;
		---
		update @CashFlow
		   set Remark = 'ICapital='+str(@ICapital)+' RCapital='+str(@RCapital)+' SCapital='+str(@SCapital)
		 where Id = @Id and Capital >= 0;
		---�Y���٥��A�ѥ��ܫ᭰�C���p���ڥ���
		select @CId = 1, @Cid_max = max(Id) from @TAK;
		while ((@ICapital > 0)and (@CId <= @Cid_max))
		begin
			---
			if (select Capital from @TAK where Id = @CId) >= @ICapital
			begin
				---
				update @CashFlow
				   set Remark = Remark + ' ('+str(@Cid)+')-ICapital='+str(@ICapital)
				 where Id = @Id and Capital >= 0;
				---
				update t
				   set Capital = Capital - @ICapital
				  from @TAK t
				 where Id = @CId;
				select @ICapital = 0;
			end
			else
			begin
				---
				update @CashFlow
				   set Remark = Remark + ' ('+str(@Cid)+')-ICapital=0'
				 where Id = @Id and Capital >= 0;
				---
				select @ICapital = @ICapital - Capital from @TAK where Id = @CId;
				update t
				   set Capital = 0
				  from @TAK t
				 where Id = @CId;
			end
			---
			select @CId = @CId + 1;
		end
		---
		if @RCapital >= @SCapital
			goto paid; ---�����w�v�٧����A�����j��
		---
		fetch next from MainCur into @CType,@Id, @TDayStr, @IRate, @ICapital, @Interest;
	end
	close MainCur; deallocate MainCur;
	---
	paid:
	---�[�p�����O�Φܲ{���y��
	insert into @CashFlow (Id, Date, Capital, Interest, Total)
	select 0 as Id,convert(datetime, dbo.so_CDToWD(�����)) as Date, 0 as Capital, 0 as Interest, ��L�O�� as Total
	  from NADET
	 where ����O = 'EXP' and �U�ڱb�� = @LoanID
	   and convert(datetime, dbo.so_CDToWD(�����)) not in (select ADay from @TAK)
	   and convert(datetime, dbo.so_CDToWD(�����)) > @SDay;
	---
	insert into @RtnValue
	select Id, Date, Capital, Interest, Total,
	       '' as Remark
	  from @CashFlow
	 order by Date asc;
	---
	set @Cnt = 10;
	while @Cnt > 0
	begin
		---
		insert into @RtnValue values (null,null,null,null,null,null);
		---
		select @Cnt = @Cnt - 1;
	end
	---
	return;
end
go

