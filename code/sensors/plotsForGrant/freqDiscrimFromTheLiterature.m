function freqDiscrimFromTheLiterature()

% Place to save figures
savePath = '~/Desktop/FlickerGrant/';

% Set up the figure
f1 = figure();
figuresize(400,200,'pt');
set(gcf,'color','w');
t = tiledlayout(1,2);
t.TileSpacing = 'tight';
t.Padding = 'none';

Waugh = [1, 0.3507798532221362
    1.4405773606943362, 0.35453048082692323
    1.6118219775228426, 0.2958909210530885
    2.0463297103685987, 0.32561325707758715
    3.118189027792709, 0.5721445609039426
    4.07151554778969, 1.0830338542656042
    5.0970286316889055, 1.1543982459533746
    6.117660411806426, 1.490081976456359
    8.10096182052068, 2.256050048137337
    10.284782740939036, 2.732056065354757
    16.346118167495977, 4.316223511301964
    20.463297103685985, 5.009207857135853
    24.56087882417325, 6.001930927220784
    26.347032509555447, 4.903782255871611
    30.747150813218337, 3.6797631115702845
    37.425768914183514, 2.9120795414381844
    ];

Mandler = [0.7159931999959236, 0.069095464583957
    1, 0.08625411361174289
    1.4899553403054262, 0.10542309931583556
    1.9931634787173167, 0.1591603415265802
    2.5264505364836904, 0.2727594565720397
    3.0019021380324205, 0.38650575360708633
    3.56682876477989, 0.4481012411151444
    4.015745671264975, 0.4625275590615493
    4.5211627357946735, 0.38244484141279084
    4.981651731888231, 0.42505033908430684
    6.24684720701418, 0.6982914061855312
    7.033068107537524, 1.0431544711253269
    7.749399427942502, 1.288521718440501
    9.109056973608602, 1.6255830952355075
    10.36663281370676, 2.454190422180611
    12.999457754928132, 3.5895984711949334
    14.635554339925248, 4.205844492778345
    19.57847434215173, 7.760831545860945
    22.042598278283183, 7.67929057223162
    30.786044166912056, 6.9829140618553085
    40.74208023384553, 3.298744080144382
    46.366839846818664, 1.6957342739806684
    ];

Vintch = [0.4609296883310279, -0.19243697478991595
1.9908945856823728, 0.02436974789915969
5.948813955962131, 0.19327731092436984
10.060036166365279, 0.38991596638655474];


nexttile
loglog(Mandler(:,1),Mandler(:,2),'sk',...
    'MarkerEdgeColor','none','MarkerFaceColor',[0.75 0.75 0.75],...
    'MarkerSize',6);
hold on
loglog(Waugh(:,1),Waugh(:,2),'^k',...
    'MarkerEdgeColor','none','MarkerFaceColor',[0.75 0.75 0.75],...
    'MarkerSize',5);

x = [Mandler(:,1); Waugh(:,1)];
y = [Mandler(:,2); Waugh(:,2)];
n = 5;
xq = logspace(log10(2),log10(46));
p = polyfit(x,y,n);
loglog(xq,polyval(p,xq),'-r','LineWidth',2);
    a = gca;
    a.TickDir = 'out';
a.YTick = ([0.1 1 10]);
a.YTickLabel = {'0.1','1','10'};
a.XTick = ([1 10 100]);
a.XTickLabel = {'1','10','100'};
xlabel('Frequency [Hz]')
ylabel('∆Frequency [Hz]')
box off
title('Discrimination threshold')
legend({'Mandler','Waugh','fit'},'Location','southeast');

nexttile
semilogx(Vintch(:,1),Vintch(:,2),'ok',...
    'MarkerEdgeColor','none','MarkerFaceColor',[0.75 0.75 0.75],...
    'MarkerSize',10);
hold on
bias = diff(polyval(p,xq).^2).*0.3;
semilogx(xq(2:end),bias,'-b','LineWidth',2);
xlim([1 100]);
    a = gca;
    a.TickDir = 'out';
%a.YTick = ([0.1 1 10]);
%a.YTickLabel = {'0.1','1','10'};
a.XTick = ([1 10 100]);
a.XTickLabel = {'1','10','100'};
xlabel('Frequency [Hz]')
ylabel('Frequency [Hz]')
box off
title('Predicted bias')
legend({'Vintch','fit'},'Location','southwest');


filename = ['DiscrimAndBiasFromLit.pdf'];
export_fig(f1,fullfile(savePath,filename),'-Painters','-transparent');

end % Function


