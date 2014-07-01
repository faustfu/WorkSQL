if object_id('fn_faust_get_REPSCH') is not null
    drop function fn_faust_get_REPSCH
go
create  function fn_faust_get_REPSCH
(
	@LoanID varchar(12)
)
returns @RtnValue table
(
	Id			smallint,	---期數
	Date		datetime,		---交易日期
	Capital		numeric(28,8),		---本
	Interest	numeric(18,8),		---息
	Total		numeric(28,8),		---和
	Remark		varchar(1000)		---備註
)
as
begin
	declare @Capital numeric(28,8),@Capital0 numeric(28,8),@IRate numeric(18,8),@Interest numeric(18,8),
	        @SDay datetime, @EDay datetime,@RCapital numeric(28,8),@SCapital numeric(28,8),
	        @DCapital numeric(28,8),@DCapital_total numeric(28,8),@DCapital_Diff numeric(28,8),
	        @TDayStr varchar(10),@ICapital numeric(28,8),@IType smallint,@Id smallint,@CType tinyint,
	        @CId smallint, @Cid_max smallint,@Cnt int;
	---撥款資料
	declare @TAK table(
		Id			int identity(1,1),
		Capital		numeric(28,8),	---本金
		Expense		numeric(28,8),	---費用
		ADay		datetime,		---入帳日
		SDay		datetime,		---計息起日
		EDay		datetime,		---計息迄日
		Period		int,			---計息區間(日/月)
		Interest	numeric(18,8)	---應計利息
	);
	---收款資料
	declare @REP table(
		Id			int identity(1,1)		,
		CType		int not null			,
		還款期數	smallint not null		,
		還款日		varchar(10) not null	,
		放款利率	numeric(18,8) not null	,
		固定還本	numeric(28,8) not null	,
		Interest	numeric(18,8) not null	,
		應計還本	numeric(28,8) not null
	);
	---金流結果
	declare @CashFlow table(
		Id			smallint,	---期數
		Date		datetime,		---交易日期
		Capital		numeric(28,8),		---本
		Interest	numeric(18,8),		---息
		Total		numeric(28,8),		---和
		Remark		varchar(1000)		---備註
	);
	---iteration=0
	select @SDay = convert(datetime, dbo.so_CDToWD(首次撥款日)),
	       @IType = 按日計息, ---1:按日計息, 2:按月計息
	       @SCapital = 累計撥款金額
      from NAMAS
     where 貸款帳號 = @LoanID;
	---撥款本金資料(一or多筆)
	insert into @TAK
	select abs(本金) as Capital, abs(撥款手續費) as Expense,
	       convert(datetime, dbo.so_CDToWD(交易日)) as ADay,
	       convert(datetime, dbo.so_CDToWD(起息日)) as SDay,
	       null as EDay, 0 as Period, 0 as Interest
	  from NADET
	 where 交易別 = 'TAK' and 貸款帳號 = @LoanID;
	---加計撥款費用
	update t
       set t.Expense = t.Expense + isnull((select sum(n.金額)
                                             from NADET n
                                            where n.交易別 = 'EXP'
                                              and n.貸款帳號 = @LoanID
                                              and convert(datetime, dbo.so_CDToWD(n.交易日)) = t.ADay), 0)
      from @TAK t;
	---加計首次撥款費用
	update t
       set t.Expense = t.Expense + isnull((select sum(n.金額)
                                             from NADET n
                                            where n.交易別 = 'EXP'
                                              and n.貸款帳號 = @LoanID
                                              and convert(datetime, dbo.so_CDToWD(n.交易日)) < @SDay), 0)
      from @TAK t
     where t.ADay = @SDay;
	---寫入實際撥款資料至現金流表
	insert into @CashFlow (Id, Date, Capital, Interest, Total)
	select 0,ADay,-1*(Capital - Expense),0,-1*(Capital - Expense)
	  from @TAK;
	--寫入應計收款及實際收款至收款表
	insert into @REP
	select * from (
	---應計收款資料
	select 1 as CType, s.還款期數, s.還款日, s.放款利率, s.固定還本, 0 as Interest, s.固定還本 as 應計還本
      from NAREPSCH s
     where s.貸款帳號 = @LoanID
       and not exists (select 1 from NADET d where d.交易別 = 'REP' and d.貸款帳號 = @LoanID and d.還款期數 = s.還款期數)
     union
	---實際收款資料
	select 2 as CType, n.還款期數, n.入帳日 as 還款日, n.放款利率, n.本金 as 固定還本, n.利息 as Interest, isnull(s.固定還本,0) as 應計還本
	  from NADET n
	  left outer join NAREPSCH s on n.貸款帳號 = s.貸款帳號 and n.還款期數 = s.還款期數
	 where n.交易別 = 'REP' and n.貸款帳號 = @LoanID
	              ) m order by m.還款日 asc;
	---針對提前還款狀況，調整還本金額
	select @RCapital = 0, @DCapital_total = 0, @DCapital_diff = 0;
	declare MainCur cursor FAST_FORWARD for
	select CType,Id,固定還本,應計還本 from @REP;
	open MainCur;
	fetch next from MainCur into @CType,@Id, @ICapital, @DCapital;
	while @@fetch_status = 0
	begin
		---
		select @RCapital = @RCapital + @ICapital, @DCapital_total = @DCapital_total + @DCapital;
		select @DCapital_Diff = @RCapital - @DCapital_total;
		---累積差額>0 => 已預付 => 扣本期應還本金, 差額<0 => 逾期 => 加本期應還本金(todo)
		if (@CType = 1)
		begin
			if @DCapital_Diff <> 0
			begin
				if @DCapital_Diff >= @ICapital
				begin
					select @RCapital = @RCapital - @ICapital, @ICapital = 0; ---預付超過本期應付還本金 => 本期不需還本
				end
				else
				begin
					select @RCapital = @RCapital - @DCapital_Diff, @ICapital = @ICapital - @DCapital_Diff; ---預付未超過本期應付還本金 => 調整本期應付還本金
				end
				---回寫調整後本期應還本金
				update r
				   set r.固定還本 = @ICapital
				  from @REP r
				 where r.Id = @Id;
			end
		end
		---
		fetch next from MainCur into @CType,@Id, @ICapital, @DCapital;
	end
	close MainCur; deallocate MainCur;
	
	---iteration=1~n
	select @RCapital = 0, @DCapital_total = 0; ---歸零實際還本加總與應計還本加總
	declare MainCur cursor FAST_FORWARD for
	select CType,還款期數,還款日,放款利率,固定還本,Interest from @REP;
	open MainCur;
	fetch next from MainCur into @CType,@Id, @TDayStr, @IRate, @ICapital, @Interest;
	while @@fetch_status = 0
	begin
		select @EDay = convert(datetime,dbo.so_CDToWD(@TDayStr));
		---更新每筆撥款計息起迄日，並將計息區間及應計息歸零
		update t
		   set t.SDay = @SDay, t.EDay = @EDay, t.Period = 0, t.Interest = 0
		  from @TAK t;
		---
		if @CType = 1
		begin
			---計算計息區間及金額
			if @IType = 1 ---0:by month, 1:by day
			begin
				---by day
				update t
	               set t.Period = case
	                                   when t.ADay > t.SDay then datediff(day, t.ADay, t.EDay)
	                                   else datediff(day, t.SDay, t.EDay)
	                              end
	              from @TAK t
	             where t.ADay < t.EDay; ---只計算落入計息範圍資料
				update t
				   set t.Interest = round((t.Capital)*@IRate*t.Period/100/365,0) ---以365天計算日利率
				  from @TAK t
				 where t.Period > 0;
			end
			else
			begin
				---by month
				update t
				   set t.Period = datediff(month,t.SDay,t.EDay)
				  from @TAK t
				 where t.ADay < t.EDay ---只計算落入計息範圍資料
				   and t.ADay <= t.SDay;
				update t
				   set t.Interest = round((t.Capital)*@IRate*t.Period/100/12,0) ---以月利率計算
				  from @TAK t
				 where t.Period > 0
				   and t.ADay <= t.SDay;
				---不足一個月，則破日計算
				update t
	               set t.Period = datediff(day, t.ADay, t.EDay)
	              from @TAK t
	             where t.ADay < t.EDay ---只計算落入計息範圍資料
	               and t.ADay > t.SDay;
				update t
				   set t.Interest = round((t.Capital)*@IRate*t.Period/100/365,0) ---以365天計算日利率
				  from @TAK t
				 where t.Period > 0
				   and t.ADay > t.SDay;
			end
			---寫入應計收款資料至現金流表
			insert into @CashFlow (Id, Date, Capital, Interest, Total)
			select @Id,@EDay,@ICapital,isnull(sum(Interest),0),@ICapital+isnull(sum(Interest),0)
			  from @TAK
			 where Interest > 0;
		end
		else
		begin
			---寫入實際收款資料至現金流表
			insert into @CashFlow (Id, Date, Capital, Interest, Total)
			values (@Id,@EDay,@ICapital,@Interest,@ICapital+@Interest);
		end
		---更新下次計息起日及總還本金額
		select @SDay = @EDay, @RCapital = @RCapital + @ICapital;
		---
		update @CashFlow
		   set Remark = 'ICapital='+str(@ICapital)+' RCapital='+str(@RCapital)+' SCapital='+str(@SCapital)
		 where Id = @Id and Capital >= 0;
		---若有還本，由先至後降低應計收款本金
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
			goto paid; ---本金已償還完畢，結束迴圈
		---
		fetch next from MainCur into @CType,@Id, @TDayStr, @IRate, @ICapital, @Interest;
	end
	close MainCur; deallocate MainCur;
	---
	paid:
	---加計期中費用至現金流表
	insert into @CashFlow (Id, Date, Capital, Interest, Total)
	select 0 as Id,convert(datetime, dbo.so_CDToWD(交易日)) as Date, 0 as Capital, 0 as Interest, 其他費用 as Total
	  from NADET
	 where 交易別 = 'EXP' and 貸款帳號 = @LoanID
	   and convert(datetime, dbo.so_CDToWD(交易日)) not in (select ADay from @TAK)
	   and convert(datetime, dbo.so_CDToWD(交易日)) > @SDay;
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

