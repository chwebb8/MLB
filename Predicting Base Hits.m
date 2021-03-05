close all; clear; clc;
%% Load and Clean Data

mlb = readtable('MLB_BattedBalls_2015.csv');

% remove columns that are game info
mlb = removevars(mlb,{'game_pk','game_date', 'game_year', 'home_team', 'away_team', 'inning_topbot'});  

% remove columns that contain venue info    
mlb = removevars(mlb,{'venue_name', 'dayNight', 'temperature', 'wind'});

% remove columns that are play indicators
mlb = removevars(mlb,{'events', 'description', 'des'});

% remove columns that list fielders
mlb = removevars(mlb,{'fielder_2', 'fielder_3', 'fielder_4', 'fielder_5', 'fielder_6', 'fielder_7', 'fielder_8', 'fielder_9'});

% remove columns that are already contained in other predictors
mlb = removevars(mlb,{'pitch_name', 'pitch_type', 'adjusted_spray_angle', 'hc_x', 'hc_y'});

% fill in hit locations for batted balls that left the ballpark (home_runs,
% ground rule doubles)
mlb.hit_location = fillmissing(mlb.hit_location,'constant',10);

% change on base from player id to Y/N
idx = find(mlb.on_1b > 1);
mlb.on_1b(idx) = 1;

idx = find(mlb.on_2b > 1);
mlb.on_2b(idx) = 1;

idx = find(mlb.on_3b > 1);
mlb.on_3b(idx) = 1;

%% Find missing values

% a few good hit data records that are missing pitch data  
% note: these were later removed
mlb.release_spin_rate(isnan(mlb.release_spin_rate))=0;
mlb.effective_speed(isnan(mlb.effective_speed))=0;

% removing remaining records with missing predictors
% 86% remains in model
ix = ismissing(mlb);
completeData = mlb(~any(ix,2),:);

%% Review and Explore data

% note: commented out code used to manually create table on poster.



%groupsummary(completeData, 'hit_out')
%summary(completeData, 'x_loc');
%summary(completeData, 'y_loc');
%summary(completeData, 'launch_angle');
%summary(completeData, 'launch_speed');
%G1 = groupsummary(completeData,'hit_out','mean',{'plate_x', 'plate_z', 'x_loc', 'y_loc'});
%G2 = groupsummary(completeData,'hit_out','std',{'plate_x', 'plate_z', 'x_loc', 'y_loc'});
%G3 = skewness(y_loc(hit_out == 'hit'));
%G4 = skewness(y_loc(hit_out == 'out'));
%G5 = skewness(y_loc(hit_out == 'error'));

%% Define Variables


effective_speed = completeData.effective_speed; %speed (mph) of pitch
release_spin_rate = completeData.release_spin_rate; %spin rate (rpm) of pitch
plate_x = completeData.plate_x; %horizontal position of ball when crosses plate. 
    %0 is center of plate (inches)
plate_z = completeData.plate_z; %vertical position of ball when crosses plate.
    %0 is plate (inches)
zone = categorical(completeData.zone); %zone of ball when crosses plate. 3x3 grid zones 1-9
    %are in the strike zone.  zones 11-14 are high/low/inside/outside
spray_angle = completeData.spray_angle; %direction angle from home plate where home plate is 0 and 
    %left is negative, right positive.  -45<x<45 is fair, else foul (foul balls are
    %not in the dataset because the ball is not in play)
hit_location = categorical(completeData.hit_location); %fielder position where ball is hit; 10 is out of park
    %1 pitcher, 2 catcher, 3 1st base, 4 2nd base, 5 3rd base, 6 shortstop, 
    %7 left field, 8 center field, 9 right field
hit_distance_sc = completeData.hit_distance_sc; %estimate distance ball was hit (feet)
x_loc = completeData.x_loc; %estimated horizontal location (feet) where ball was hit
    % with 0 being home plate
y_loc = completeData.y_loc; %estimate vertical location (feet) where ball was hit
    % with 0 being perpindicular to home plate
launch_speed = completeData.launch_speed; %speed the ball was hit with bat (mph)
launch_angle = completeData.launch_angle; %angle the ball was hit with bat (degrees)
    % with 0 being parallel to ground


%% plotting correlation matrices

% borrowed from matlab answers forum
% https://www.mathworks.com/matlabcentral/answers/42026-undefined-function-corrplot
p_data = [effective_speed, release_spin_rate, plate_x, plate_z];
nVars = size(p_data,2); 

% Create plotmatrix
figure('Name', 'Pitching Correlation Matrix')
[sh, ax, ~, hh] = plotmatrix(p_data);
% Add axis labels
arrayfun(@(h,lab)ylabel(h,lab),ax(:,1), {'pitch speed','spin rate','plate x','plate z'}')
arrayfun(@(h,lab)xlabel(h,lab),ax(end,:), {'pitch speed','spin_rate','plate x','plate z'})
% Compute correlation for each scatter plot axis
[r,p] = arrayfun(@(h)corr(h.Children.XData(:),h.Children.YData(:)),ax(~eye(nVars)));
% Label the correlation and p values
arrayfun(@(h,r,p)text(h,min(xlim(h))+range(xlim(h))*.05,max(ylim(h)),...
    sprintf('r=%.2f,  p=%.3f',r,p),'Horiz','Left','Vert','top','FontSize',8,'Color','r'),...
    ax(~eye(nVars)),r,p)
% Change marker appearance
set(sh, 'Marker', 'o','MarkerSize', 2, 'MarkerEdgeColor', ax(1).ColorOrder(1,:)) 
lsh = arrayfun(@(h)lsline(h),ax(~eye(nVars)));
% Add least square regression line. 
set(lsh,'color', 'm')


h_data = [launch_speed, launch_angle, x_loc, y_loc];
nVars = size(h_data,2); 

% Create plotmatrix
figure('Name', 'Hitting Correlation Matrix')
[sh, ax, ~, hh] = plotmatrix(h_data);
% Add axis labels
arrayfun(@(h,lab)ylabel(h,lab),ax(:,1), {'launch speed','launch angle','x loc','y loc'}')
arrayfun(@(h,lab)xlabel(h,lab),ax(end,:), {'launch speed','launch angle','x loc','y loc'})
% Compute correlation for each scatter plot axis
[r,p] = arrayfun(@(h)corr(h.Children.XData(:),h.Children.YData(:)),ax(~eye(nVars)));
% Label the correlation and p values
arrayfun(@(h,r,p)text(h,min(xlim(h))+range(xlim(h))*.05,max(ylim(h)),...
    sprintf('r=%.2f,  p=%.3f',r,p),'Horiz','Left','Vert','top','FontSize',8,'Color','r'),...
    ax(~eye(nVars)),r,p)
% Change marker appearance
set(sh, 'Marker', 'o','MarkerSize', 2, 'MarkerEdgeColor', ax(1).ColorOrder(1,:)) 
lsh = arrayfun(@(h)lsline(h),ax(~eye(nVars)));
% Add least square regression line. 
set(lsh,'color', 'm')

%% More data clean up

% Graphs show 0 for release_spin_rate and effective_speed influence
% correlation quite a bit so remove these records from completeData

completeData(completeData.effective_speed == 0, :) = [];
completeData(completeData.release_spin_rate == 0, :) = [];

% refresh variables
effective_speed = completeData.effective_speed;
release_spin_rate = completeData.release_spin_rate; 
plate_x = completeData.plate_x; 
plate_z = completeData.plate_z; 
hit_location = categorical(completeData.hit_location);
hit_distance_sc = completeData.hit_distance_sc; 
spray_angle = completeData.spray_angle;
x_loc = completeData.x_loc; 
y_loc = completeData.y_loc; 
launch_speed = completeData.launch_speed; 
launch_angle = completeData.launch_angle; 
hit_out = categorical(completeData.hit_out);
pitcher = completeData.pitcher;


%new variables for more data analysis
bb_type = categorical(completeData.bb_type); %type of batted ball 
   %(in in the air, on the ground, or line drive)
pitch_code = categorical(completeData.pitch_code); %type of pitch
  %(fast ball, curve ball, breaking ball, etc)
match_up = categorical(completeData.match_up); %R/L pitching arm 
  %vs R/L Batter Stance
count = categorical(completeData.count); %Balls vs Strikes
p_throws = categorical(completeData.p_throws); %pitcher throw arm
stand = categorical(completeData.stand); %batter stand side



%% Rerun pitching correlation

% create first figure again with removed outliers
p_data = [effective_speed, release_spin_rate, plate_x, plate_z];
nVars = size(p_data,2); 

% Create plotmatrix
figure('Name','Revised Pitching Correlation Matrix')
[sh, ax, ~, hh] = plotmatrix(p_data);
% Add axis labels
arrayfun(@(h,lab)ylabel(h,lab),ax(:,1), {'pitch speed','spin rate','plate x','plate z'}')
arrayfun(@(h,lab)xlabel(h,lab),ax(end,:), {'pitch speed','spin rate','plate x','plate z'})
% Compute correlation for each scatter plot axis
[r,p] = arrayfun(@(h)corr(h.Children.XData(:),h.Children.YData(:)),ax(~eye(nVars)));
% Label the correlation and p values
arrayfun(@(h,r,p)text(h,min(xlim(h))+range(xlim(h))*.05,max(ylim(h)),...
    sprintf('r=%.2f,  p=%.3f',r,p),'Horiz','Left','Vert','top','FontSize',8,'Color','r'),...
    ax(~eye(nVars)),r,p)
% Change marker appearance
set(sh, 'Marker', 'o','MarkerSize', 2, 'MarkerEdgeColor', ax(1).ColorOrder(1,:)) 
lsh = arrayfun(@(h)lsline(h),ax(~eye(nVars)));
% Add least square regression line. 
set(lsh,'color', 'm')

%% More Analysis

% mapping hits, outs, errors using the x,y data points
figure(4)
hold on
scatter(x_loc(hit_out =='out'),y_loc(hit_out=='out'),10, [0.8500, 0.3250, 0.0980], 'Marker', 'x')
scatter(x_loc(hit_out =='hit'),y_loc(hit_out=='hit'),10, [0, 0.4470, 0.7410], 'Marker', '.')
scatter(x_loc(hit_out =='error'),y_loc(hit_out=='error'),1, 'g', 'Marker', 'o')
title('Batted Balls Location')
legend('out', 'hit', 'error')
ylim([-25 500]);
hold off


 
%% extra graphs but may not be needed for this exercise 

% like above but x,y points from pitch where ball is at home plate
% with rectangle representing the strike zone

figure(5)
hold on
scatter(plate_x(hit_out =='out'),plate_z(hit_out=='out'),5, 'r', 'Marker', 'x')
scatter(plate_x(hit_out =='hit'),plate_z(hit_out=='hit'),5, 'b', 'Marker', '.')
%scatter(plate_x(hit_out =='error'),plate_z(hit_out=='error'),1, 'g', 'Marker', 'o')
title('Pitch Location')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
xlim([-2.4 2.4])
ylim([0.2 4.8])
legend('Out', 'Hit')
hold off

%% An Attempt to create a heat map for different match ups

% did not find this to prove descriptive or look as well as 
% hoped; struggled with finding the correct colormap.

dataxHRR = plate_x(hit_out =='hit' & stand == 'R' & p_throws == 'R');
datayHRR = plate_z(hit_out=='hit' & stand == 'R' & p_throws == 'R');
[valuesHRR, centersHRR] = hist3([dataxHRR(:) datayHRR(:)],[20 20]);

dataxORR = plate_x(hit_out =='out' & stand == 'R' & p_throws == 'R');
datayORR = plate_z(hit_out=='out' & stand == 'R' & p_throws == 'R');
[valuesORR, centersORR] = hist3([dataxORR(:) datayORR(:)],[20 20]);

dataxHLR = plate_x(hit_out =='hit' & stand == 'R' & p_throws == 'L');
datayHLR = plate_z(hit_out=='hit' & stand == 'R' & p_throws == 'L');
[valuesHLR, centersHLR] = hist3([dataxHLR(:) datayHLR(:)],[20 20]);

dataxOLR = plate_x(hit_out =='out' & stand == 'R' & p_throws == 'L');
datayOLR = plate_z(hit_out=='out' & stand == 'R' & p_throws == 'L');
[valuesOLR, centersOLR] = hist3([dataxOLR(:) datayOLR(:)],[20 20]);


dataxHRL = plate_x(hit_out =='hit' & stand == 'L' & p_throws == 'R');
datayHRL = plate_z(hit_out=='hit' & stand == 'L' & p_throws == 'R');
[valuesHRL, centersHRL] = hist3([dataxHRL(:) datayHRL(:)],[20 20]);

dataxORL = plate_x(hit_out =='out' & stand == 'L' & p_throws == 'R');
datayORL = plate_z(hit_out=='out' & stand == 'L' & p_throws == 'R');
[valuesORL, centersORL] = hist3([dataxORL(:) datayORL(:)],[20 20]);

dataxHLL = plate_x(hit_out =='hit' & stand == 'L' & p_throws == 'L');
datayHLL = plate_z(hit_out=='hit' & stand == 'L' & p_throws == 'L');
[valuesHLL, centersHLL] = hist3([dataxHLL(:) datayHLL(:)],[20 20]);

dataxOLL = plate_x(hit_out =='out' & stand == 'L' & p_throws == 'L');
datayOLL = plate_z(hit_out=='out' & stand == 'L' & p_throws == 'L');
[valuesOLL, centersOLL] = hist3([dataxOLL(:) datayOLL(:)],[20 20]);


mymap = [1 1 1
    0.5 0.25 0.5
    0 0.5 0
    0.5 0.75 0.5
    1 0 0];


figure(6)
hold on
subplot(2,4,1)
imagesc(centersHLL{:}, valuesHLL.')
colorbar 'off'
colormap(mymap)
title('L v L Hits')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
subplot(2,4,2)
imagesc(centersHRL{:}, valuesHRL.')
colorbar 'off'
colormap(mymap)
title('R v L Hits')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
subplot(2,4,3)
imagesc(centersHLR{:}, valuesHLR.')
colorbar 'off'
colormap(mymap)
title('L v R Hits')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal')
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
subplot(2,4,4)
imagesc(centersHRR{:}, valuesHRR.')
colorbar 'off'
colormap(mymap)
title('R v R Hits')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46])  
subplot(2,4,5)
imagesc(centersOLL{:}, valuesOLL.')
colorbar 'off'
colormap(mymap)
title('L v L Outs')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
subplot(2,4,6)
imagesc(centersORL{:}, valuesORL.')
colorbar 'off'
colormap(mymap)
title('R v L Outs')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
subplot(2,4,7)
imagesc(centersOLR{:}, valuesOLR.')
colorbar 'off'
colormap(mymap)
title('L v R Outs')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
subplot(2,4,8)
imagesc(centersORR{:}, valuesORR.')
colorbar 'off'
colormap(mymap)
title('R v R Outs')
rectangle('Position', [-0.71, 1.58, 1.42, 1.86])
set(gca,'YDir','normal') 
xlim([-1.86 1.86])
ylim([0.42 4.46]) 
suptitle('Pitching Battles')
hold off

% commented out code below was attempting batted balls with angle and type

%figure
%hold on
%scatter(spray_angle(bb_type == 'ground_ball'), hit_distance_sc(bb_type == 'ground_ball'), 5, 'b', 'Marker', '.')
%scatter(spray_angle(bb_type == 'fly_ball'), hit_distance_sc(bb_type == 'fly_ball'), 5, 'r', 'Marker', 'x')
%scatter(spray_angle(bb_type == 'line_drive'), hit_distance_sc(bb_type == 'line_drive'), 5, 'g', 'Marker', 'o')
%hold off

%xlim([-2.4 2.4])
%ylim([0.2 4.8])

%% Histograms

% plot matrix of some predictors but ended up using different format for
% poster

figure(7)
hold on
subplot(3,3,1)
h1 = histogram(completeData.spray_angle);
h1.EdgeColor = 'none';
title('Spray Angle (degrees)')
subplot(3,3,2)
h2 = histogram(completeData.launch_angle);
h2.EdgeColor = 'none';
title('Launch Angle (degrees)')
subplot(3,3,3)
h3 = histogram(completeData.launch_speed);
h3.EdgeColor = 'none';
title('Launch Speed (mph)')
subplot(3,3,4)
h4 = histogram(completeData.hit_distance_sc);
h4.EdgeColor = 'none';
title('Hit Distance (feet)')
subplot(3,3,5)
h5 = histogram(completeData.hit_location);
h5.EdgeColor = 'none';
title('Hit Location (position)')
subplot(3,3,6)
h6 = histogram(pitch_code);
h6.EdgeColor = 'none';
title('Pitch Code')
subplot(3,3,7)
h7 = histogram(match_up);
h7.EdgeColor = 'none';
title('Pitcher vs Batter')
subplot(3,3,8)
h8 = histogram(count);
h8.EdgeColor = 'none';
title('Pitch Count')
subplot(3,3,9)
h9 = histogram(hit_out, 'FaceColor', [0.8500, 0.3250, 0.0980]);
h9.EdgeColor = 'none';
title('Hit or Out')
suptitle('Histogram of some Key Predictors')
hold off


%% clean up bb_type for histogram

% class names have underscore which matlab treats as subscript.
% updating and removing those for cleaner histograms

idx = find(bb_type == 'line_drive');
bb_type(idx) = 'line drive';
idx = find(bb_type == 'ground_ball');
bb_type(idx) = 'ground ball';
idx = find(bb_type == 'fly_ball');
bb_type(idx) = 'fly ball';

bb_type = removecats(bb_type, {'fly_ball', 'ground_ball', 'line_drive'}) ;  


%% More Histograms

% series of histograms to use on the poster to show the differences between
% hit and out in a few predictors

figure(8)
ls_h = launch_speed(hit_out == 'hit');
ls_o = launch_speed(hit_out == 'out');
h2 = histogram(ls_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(ls_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Launch Speed');
hold off

figure(9)
hd_h = hit_distance_sc(hit_out == 'hit');
hd_o = hit_distance_sc(hit_out == 'out');
h2 = histogram(hd_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(hd_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northeast');
title('Hit Distance');
hold off


figure(10)
bbt_h = bb_type(hit_out == 'hit');
bbt_o = bb_type(hit_out == 'out');
h2 = histogram(bbt_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(bbt_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Type of Batted Ball');
hold off


figure(11)
hl_h = hit_location(hit_out == 'hit');
hl_o = hit_location(hit_out == 'out');
h2 = histogram(hl_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(hl_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Hit Location');
hold off

figure(28)
la_h = launch_angle(hit_out == 'hit');
la_o = launch_angle(hit_out == 'out');
h2 = histogram(la_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(la_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Launch Angle');
hold off

figure(29)
es_h = effective_speed(hit_out == 'hit');
es_o = effective_speed(hit_out == 'out');
h2 = histogram(es_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(es_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Pitch Speed');
hold off

figure(30)
z_h = zone(hit_out == 'hit');
z_o = zone(hit_out == 'out');
h2 = histogram(z_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(z_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Pitch Zone');
hold off


figure(31)
px_h = plate_x(hit_out == 'hit');
px_o = plate_x(hit_out == 'out');
h2 = histogram(px_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(px_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Plate Horizontal Position');
hold off


figure(32)
pz_h = plate_z(hit_out == 'hit');
pz_o = plate_z(hit_out == 'out');
h2 = histogram(pz_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(pz_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Plate Vertical Position');
hold off

figure(33)
rsr_h = release_spin_rate(hit_out == 'hit');
rsr_o = release_spin_rate(hit_out == 'out');
h2 = histogram(rsr_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(rsr_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Pitch Spin Rate');
hold off


figure(33)
sa_h = spray_angle(hit_out == 'hit');
sa_o = spray_angle(hit_out == 'out');
h2 = histogram(sa_o);
h2.FaceColor = [0.8500, 0.3250, 0.0980];
hold on
h1 = histogram(sa_h);
h1.FaceColor = [0, 0.4470, 0.7410];
legend('out','hit', 'Location', 'Northwest');
title('Spray Angle');
hold off


%% Data Normalization and final clean up


% remove columns that are combination of others but kept for initial
% analysis
completeData = removevars(completeData,{'match_up', 'count','pitcher', 'batter'});

% simplify problem by assuming without an error, batted ball would have
% been an out 
completeData.hit_out(strcmp(completeData.hit_out,'error')) = {'out'};

% inital fitting rarely ever predicted an error since due to the logic of
% classifying an error during a actual baseball game means it should
% have been an out if it were not from a mistake made by a fielder, this
% seems like a reasonable change to me

%% Normalize Data 


% copy of data
normData = completeData;

% string to numeric categories
normData.hit_out = grp2idx(normData.hit_out);
normData.stand = grp2idx(normData.stand);
normData.pitch_code = grp2idx(normData.pitch_code);
normData.p_throws = grp2idx(normData.p_throws);
normData.bb_type = grp2idx(normData.bb_type);
normData.if_fielding_alignment = grp2idx(normData.if_fielding_alignment);
normData.of_fielding_alignment = grp2idx(normData.of_fielding_alignment);
normData.turftype = grp2idx(normData.turftype);


% add +1 to remove zero
normData.balls = normData.balls + 1;
normData.strikes = normData.strikes + 1;
normData.outs_when_up = normData.outs_when_up + 1;
normData.on_1b = normData.on_1b + 1;
normData.on_2b = normData.on_2b + 1;
normData.on_3b = normData.on_3b + 1;

% set a hit to 1 and out to 0
idx = find(normData.hit_out > 1);
normData.hit_out(idx) = 0;


% normalize numeric 
normData.effective_speed = normalize(normData.effective_speed, 'range');
normData.release_spin_rate = normalize(normData.release_spin_rate, 'range');
normData.plate_x = normalize(normData.plate_x, 'range');
normData.plate_z = normalize(normData.plate_z, 'range');
normData.hit_location = normalize(normData.hit_location, 'range');
normData.hit_distance_sc = normalize(normData.hit_distance_sc, 'range');
normData.spray_angle = normalize(normData.spray_angle, 'range');
normData.x_loc = normalize(normData.x_loc, 'range');
normData.y_loc = normalize(normData.y_loc, 'range');
normData.launch_speed = normalize(normData.launch_speed, 'range');
normData.launch_angle = normalize(normData.launch_angle, 'range');
normData.leftline = normalize(normData.leftline, 'range');
normData.leftcenter = normalize(normData.leftcenter, 'range');
normData.center = normalize(normData.center, 'range');
normData.rightcenter = normalize(normData.rightcenter, 'range');
normData.rightline = normalize(normData.rightline, 'range');



normData = table2array(normData);

%% Split into Training and Testing 


% Cross validation
rng('default') % for reproducibility
cv = cvpartition(length(normData),'Holdout',.20);
idx = cv.test;

% Separate to training and test data
trainData = normData(~idx,:);
testData  = normData(idx,:);

y_test = testData(:,1);
x_test = testData(:,2:end);


cv = cvpartition(length(trainData),'KFold',10);

y_train = trainData(:,1);
x_train = trainData(:,2:end);



%% Plotting k fold partition

% plot to confirm reasonable distribution of classes between all 10 folds

classLabels = [0, 1]';

numClasses = length(classLabels);
numFolds = cv.NumTestSets;
nTestData = zeros(numFolds,numClasses);

for i = 1:numFolds
    testClasses = y_train(cv.test(i));
    nCounts = groupcounts(testClasses); % Number of test set observations in each class
    nTestData(i,:) = nCounts';
end

bar(nTestData)
xlabel('Test Set (Fold)')
ylabel('Number of Observations')
title('Nonstratified Partition')
legend({'hit', 'out'}, 'Location', 'northeastoutside')



%% Initial Model Building

% use F link function from tutorials in logistic regression

link = @(mu) log(mu ./ (1-mu));
derlink = @(mu) 1 ./ (mu .* (1-mu));
invlink = @(resp) 1 ./ (1 + exp(-resp));
F = {link, derlink, invlink};


% pass through 10 folds in a loop between multiple models at a time

for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,:);
    idx = test(cv,i);
    validation = trainData(idx,:);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = train(:,1);
    x_train = train(:,2:end);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
     
    
    
    % Logistic Regression
    
    MDLglm{i} = glmfit(x_train,y_train,'binomial'); %,'link',F);
    
    
    % store off these results using the i loops
    % validation
    ypred = predict_ml(MDLglm{i},x_validation); 
    yh = glmval(MDLglm{i},x_validation,F);
    
    yhat{i} = [ypred, yh, 1-yh, 1-yh, yh];
    y_val{i} = y_validation;
    MSE{i} = mean((y_validation - yh).^2);   
    
    RES{i} = confusionmat(y_validation,ypred);     
    Accuracy{i} = (RES{i}(1,1)+RES{i}(2,2))/(RES{i}(1,1)+RES{i}(2,2)+RES{i}(2,1)+RES{i}(1,2));  
    Precision{i} = RES{i}(1,1)/(RES{i}(1,1)+RES{i}(2,1));  
    Recall{i} = RES{i}(1,1)/(RES{i}(1,1)+RES{i}(1,2));  
    F1{i} = 2*(Recall{i} * Precision{i}) / (Recall{i} + Precision{i});   
 

    
    
    
    % Fit discriminant analysis classifier - not used in project but
    % testing different methods
    
    MDLcd{i} = fitcdiscr(x_train,y_train);
    
    % for ROC graphing
    y_val{i+10} = y_validation; 
    
    ypred = predict(MDLcd{i},x_validation);  
    
    [label, score, cost] = predict(MDLcd{i},x_validation);
    yhat{i+10} = [label, score, cost];
    MSE{i+10} = mean((y_validation - yhat{i+10}(:,2)).^2);   
    
    RES{i+10} = confusionmat(y_validation,ypred);     
    Accuracy{i+10} = (RES{i+10}(1,1)+RES{i+10}(2,2))/(RES{i+10}(1,1)+RES{i+10}(2,2)+RES{i+10}(2,1)+RES{i+10}(1,2));  
    Precision{i+10} = RES{i+10}(1,1)/(RES{i+10}(1,1)+RES{i+10}(2,1));  
    Recall{i+10} = RES{i+10}(1,1)/(RES{i+10}(1,1)+RES{i+10}(1,2));  
    F1{i+10} = 2*(Recall{i+10} * Precision{i+10}) / (Recall{i+10} + Precision{i+10});  
    
    
    
    % Naive Bayes
    MDLnb{i} =  fitcnb(x_train,y_train);    
    
      
    ypred = predict(MDLnb{i},x_validation); 
    
    [label, score, cost] = predict(MDLnb{i},x_validation);
    yhat{i+20} = [label, score, cost];
    MSE{i+20} = mean((y_validation - yhat{i+20}(:,2)).^2);   
    
    RES{i+20} = confusionmat(y_validation,ypred);     
    Accuracy{i+20} = (RES{i+20}(1,1)+RES{i+20}(2,2))/(RES{i+20}(1,1)+RES{i+20}(2,2)+RES{i+20}(2,1)+RES{i+20}(1,2));  
    Precision{i+20} = RES{i+20}(1,1)/(RES{i+20}(1,1)+RES{i+20}(2,1));  
    Recall{i+20} = RES{i+20}(1,1)/(RES{i+20}(1,1)+RES{i+20}(1,2));  
    F1{i+20} = 2*(Recall{i+20} * Precision{i+20}) / (Recall{i+20} + Precision{i+20});   
    
    
end




%%  ROC

%[X,Y,T,AUC] = perfcurve(y_train,scores,classLabels(1,1));

% plotted the 10 folds in LR to see how they performed 

%fitglm
[X1, Y1, ~, AUC1] = perfcurve(y_val{1,1}, yhat{1,1}(:,2), 1);
[X2, Y2, ~, AUC2] = perfcurve(y_val{1,2}, yhat{1,2}(:,2), 1);
[X3, Y3, ~, AUC3] = perfcurve(y_val{1,3}, yhat{1,3}(:,2), 1);
[X4, Y4, ~, AUC4] = perfcurve(y_val{1,4}, yhat{1,4}(:,2), 1);
[X5, Y5, ~, AUC5] = perfcurve(y_val{1,5}, yhat{1,5}(:,2), 1);
[X6, Y6, ~, AUC6] = perfcurve(y_val{1,6}, yhat{1,6}(:,2), 1);
[X7, Y7, ~, AUC7] = perfcurve(y_val{1,7}, yhat{1,7}(:,2), 1);
[X8, Y8, ~, AUC8] = perfcurve(y_val{1,8}, yhat{1,8}(:,2), 1);
[X9, Y9, ~, AUC9] = perfcurve(y_val{1,9}, yhat{1,9}(:,2), 1);
[X10, Y10, ~, AUC10] = perfcurve(y_val{1,10}, yhat{1,10}(:,2), 1);



AUCs = [1, AUC1; 2, AUC2; 3, AUC3; 4, AUC4; 5, AUC5;...
      6, AUC6; 7, AUC7; 8, AUC8; 9, AUC9; 10, AUC10]; 

statAUC = [min(AUCs(:,2)), max(AUCs(:,2))]';


figure(12)
plot(X1, Y1)
hold on
plot(X2, Y2)
plot(X3, Y3)
plot(X4, Y4)
plot(X5, Y5)
plot(X6, Y6)
plot(X7, Y7)
plot(X8, Y8)
plot(X9, Y9)
plot(X10, Y10)
legend('1', '2', '3', '4', '5', '6', '7', '8', '9', '10')
xlabel('False positive rate'); 
ylabel('True positive rate');
title('ROC Curves for Logistic Regression')
hold off


% highlighted the model that had the best accuracy

figure(13)
hold on
for i = 1:length(AUCs)
    h=bar(AUCs(i,1),AUCs(i,2));
    if AUCs(i,2) == statAUC(2,1)
        set(h,'FaceColor','r');
    else
        set(h,'FaceColor','b');
    end
end
hold off
ylim([(statAUC(2,1) - 0.05) (statAUC(2,1) + 0.01)])
title('AUC for Logistic Regression Models')




%% Lasso
% simplify model by removing unnecessary predictors

y_train = trainData(:,1);
x_train = trainData(:,2:end);

[b,fitinfo] = lasso(x_train,y_train,'CV',10);

%% Plot the variables

lassoPlot(b,fitinfo,'PlotType','Lambda','XScale','log');

%% Calculate lambda from lasso


lam = fitinfo.Index1SE;
fitinfo1SE = fitinfo.MSE(lam);
b1SE = b(:,lam);

%% take 1SE and remove predictors that are less important


%Re-run models NB and Logistic Regression with only these dependent
%variables



link = @(mu) log(mu ./ (1-mu));
derlink = @(mu) 1 ./ (mu .* (1-mu));
invlink = @(resp) 1 ./ (1 + exp(-resp));
F = {link, derlink, invlink};


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
    
    
  
    
    
    % Logistic Regression
    % confirmed F function and logit achieve the same results
    
    MDLglm{i+10} = glmfit(x_train,y_train,'binomial','link',F);
    %mdl{i} = fitglm(x_train,y_train,'Distribution', 'binomial');
    

    
    % validation
    ypred = predict_ml(MDLglm{i+10},x_validation); 
    yh = glmval(MDLglm{i+10},x_validation,F);
    
    yhat{i+30} = [ypred, yh, 1-yh, 1-yh, yh];
    y_val{i+30} = y_validation;
    MSE{i+30} = mean((y_validation - yh).^2);   
    
    RES{i+30} = confusionmat(y_validation,ypred);     
    Accuracy{i+30} = (RES{i+30}(1,1)+RES{i+30}(2,2))/(RES{i+30}(1,1)+RES{i+30}(2,2)+RES{i+30}(2,1)+RES{i+30}(1,2));  
    Precision{i+30} = RES{i+30}(1,1)/(RES{i+30}(1,1)+RES{i+30}(2,1));  
    Recall{i+30} = RES{i+30}(1,1)/(RES{i+30}(1,1)+RES{i+30}(1,2));  
    F1{i+30} = 2*(Recall{i+30} * Precision{i+30}) / (Recall{i+30} + Precision{i+30});   
 
       
    
    % Naive Bayes
    MDLnb{i+10} =  fitcnb(x_train,y_train);    
    
    ypred = predict(MDLnb{i+10},x_validation); 
    
    [label, score, cost] = predict(MDLnb{i+10},x_validation);
    yhat{i+40} = [label, score, cost];
    MSE{i+40} = mean((y_validation - yhat{i+40}(:,2)).^2);   
    
    RES{i+40} = confusionmat(y_validation,ypred);     
    Accuracy{i+40} = (RES{i+40}(1,1)+RES{i+40}(2,2))/(RES{i+40}(1,1)+RES{i+40}(2,2)+RES{i+40}(2,1)+RES{i+40}(1,2));  
    Precision{i+40} = RES{i+40}(1,1)/(RES{i+40}(1,1)+RES{i+40}(2,1));  
    Recall{i+40} = RES{i+40}(1,1)/(RES{i+40}(1,1)+RES{i+40}(1,2));  
    F1{i+40} = 2*(Recall{i+40} * Precision{i+40}) / (Recall{i+40} + Precision{i+40});   
    
    
end



%% Plot Results for updated model with fewer predictors


%fitglm
[X1, Y1, ~, AUC31] = perfcurve(y_val{1,31}, yhat{1,31}(:,2), 1);
[X2, Y2, ~, AUC32] = perfcurve(y_val{1,32}, yhat{1,32}(:,2), 1);
[X3, Y3, ~, AUC33] = perfcurve(y_val{1,33}, yhat{1,33}(:,2), 1);
[X4, Y4, ~, AUC34] = perfcurve(y_val{1,34}, yhat{1,34}(:,2), 1);
[X5, Y5, ~, AUC35] = perfcurve(y_val{1,35}, yhat{1,35}(:,2), 1);
[X6, Y6, ~, AUC36] = perfcurve(y_val{1,36}, yhat{1,36}(:,2), 1);
[X7, Y7, ~, AUC37] = perfcurve(y_val{1,37}, yhat{1,37}(:,2), 1);
[X8, Y8, ~, AUC38] = perfcurve(y_val{1,38}, yhat{1,38}(:,2), 1);
[X9, Y9, ~, AUC39] = perfcurve(y_val{1,39}, yhat{1,39}(:,2), 1);
[X10, Y10, ~, AUC40] = perfcurve(y_val{1,40}, yhat{1,40}(:,2), 1);



AUCs = [1, AUC31; 2, AUC32; 3, AUC33; 4, AUC34; 5, AUC35;...
      6, AUC36; 7, AUC37; 8, AUC38; 9, AUC39; 10, AUC40]; 

statAUC = [min(AUCs(:,2)), max(AUCs(:,2))]';


figure(15)
plot(X1, Y1)
hold on
plot(X2, Y2)
plot(X3, Y3)
plot(X4, Y4)
plot(X5, Y5)
plot(X6, Y6)
plot(X7, Y7)
plot(X8, Y8)
plot(X9, Y9)
plot(X10, Y10)
legend('1', '2', '3', '4', '5', '6', '7', '8', '9', '10')
xlabel('False positive rate'); 
ylabel('True positive rate');
title('ROC Curves for Logistic Regression after Lasso Regularlization')
hold off


figure(16)
hold on
for i = 1:length(AUCs)
    h=bar(AUCs(i,1),AUCs(i,2));
    if AUCs(i,2) == statAUC(2,1)
        set(h,'FaceColor','r');
    else
        set(h,'FaceColor','b');
    end
end
hold off
ylim([(statAUC(2,1) - 0.05) (statAUC(2,1) + 0.01)])
title('AUC for Logistic Regression Models after Lasso Regularization')




%% Optimizing Naive Bayes


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
    

    % using kernel distribution with prior based on 2015 averages
    
    % Naive Bayes
    MDLnb{i+20} =  fitcnb(x_train,y_train, 'DistributionNames', {'kernel', 'kernel', 'kernel', 'kernel',...
        'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel'},...
        'Prior', [0.3227 0.6773]);    
    

    
    ypred = predict(MDLnb{i+20},x_validation); 
    
    [label, score, cost] = predict(MDLnb{i+20},x_validation);
    yhat{i+50} = [label, score, cost];
    MSE{i+50} = mean((y_validation - yhat{i+50}(:,2)).^2);   
    
    RES{i+50} = confusionmat(y_validation,ypred);     
    Accuracy{i+50} = (RES{i+50}(1,1)+RES{i+50}(2,2))/(RES{i+50}(1,1)+RES{i+50}(2,2)+RES{i+50}(2,1)+RES{i+50}(1,2));  
    Precision{i+50} = RES{i+50}(1,1)/(RES{i+50}(1,1)+RES{i+50}(2,1));  
    Recall{i+50} = RES{i+50}(1,1)/(RES{i+50}(1,1)+RES{i+50}(1,2));  
    F1{i+50} = 2*(Recall{i+50} * Precision{i+50}) / (Recall{i+50} + Precision{i+50});   

end

%% Only using Prior since long run time to create kernel model


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
    

    
    
    % Naive Bayes
    MDLnb{i+30} =  fitcnb(x_train,y_train, 'Prior', [0.35 0.65]);    
    

    
    ypred = predict(MDLnb{i+30},x_validation); 
    
    [label, score, cost] = predict(MDLnb{i+30},x_validation);
    yhat{i+60} = [label, score, cost];
    MSE{i+60} = mean((y_validation - yhat{i+60}(:,2)).^2);   
    
    RES{i+60} = confusionmat(y_validation,ypred);     
    Accuracy{i+60} = (RES{i+60}(1,1)+RES{i+60}(2,2))/(RES{i+60}(1,1)+RES{i+60}(2,2)+RES{i+60}(2,1)+RES{i+60}(1,2));  
    Precision{i+60} = RES{i+60}(1,1)/(RES{i+60}(1,1)+RES{i+60}(2,1));  
    Recall{i+60} = RES{i+60}(1,1)/(RES{i+60}(1,1)+RES{i+60}(1,2));  
    F1{i+60} = 2*(Recall{i+60} * Precision{i+60}) / (Recall{i+60} + Precision{i+60});   

end



%% Multivariate Multinomial

for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
    

    % adjust the distributions to be mvmn for categorical variables
    % and remove the prior since it was not helping
    
    % Naive Bayes
    MDLnb{i+40} =  fitcnb(x_train,y_train, 'DistributionNames', {'mvmn', 'kernel', 'mvmn', 'mvmn',...
        'mvmn', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel'});    
    

    
    ypred = predict(MDLnb{i+40},x_validation); 
    
    [label, score, cost] = predict(MDLnb{i+40},x_validation);
    yhat{i+70} = [label, score, cost];
    MSE{i+70} = mean((y_validation - yhat{i+70}(:,2)).^2);   
    
    RES{i+70} = confusionmat(y_validation,ypred);     
    Accuracy{i+70} = (RES{i+70}(1,1)+RES{i+70}(2,2))/(RES{i+70}(1,1)+RES{i+70}(2,2)+RES{i+70}(2,1)+RES{i+70}(1,2));  
    Precision{i+70} = RES{i+70}(1,1)/(RES{i+70}(1,1)+RES{i+70}(2,1));  
    Recall{i+70} = RES{i+70}(1,1)/(RES{i+70}(1,1)+RES{i+70}(1,2));  
    F1{i+70} = 2*(Recall{i+70} * Precision{i+70}) / (Recall{i+70} + Precision{i+70});   

end

%% Logistic Regression Optimization



link = @(mu) log(mu ./ (1-mu));
derlink = @(mu) 1 ./ (mu .* (1-mu));
invlink = @(resp) 1 ./ (1 + exp(-resp));
F = {link, derlink, invlink};


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
    
    
    % Logistic Regression
    % try with the probit function; slightly different results but did not
    % include in poster analysis
    
    MDLglm{i+20} = glmfit(x_train,y_train,'binomial','link','probit');
    %mdl{i} = fitglm(x_train,y_train,'Distribution', 'binomial');
    
    
    
    
    
    % validation
    ypred = predict_ml(MDLglm{i+20},x_validation); 
    yh = glmval(MDLglm{i+20},x_validation,F);
    
    yhat{i+80} = [ypred, yh, 1-yh, 1-yh, yh];
    y_val{i+80} = y_validation;
    MSE{i+80} = mean((y_validation - yh).^2);   
    
    RES{i+80} = confusionmat(y_validation,ypred);     
    Accuracy{i+80} = (RES{i+80}(1,1)+RES{i+80}(2,2))/(RES{i+80}(1,1)+RES{i+80}(2,2)+RES{i+80}(2,1)+RES{i+80}(1,2));  
    Precision{i+80} = RES{i+80}(1,1)/(RES{i+80}(1,1)+RES{i+80}(2,1));  
    Recall{i+80} = RES{i+80}(1,1)/(RES{i+80}(1,1)+RES{i+80}(1,2));  
    F1{i+80} = 2*(Recall{i+80} * Precision{i+80}) / (Recall{i+80} + Precision{i+80});   
 
end 


%% Logistic Regression Optimization


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    y_train = y_train +1;
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);
    y_validation = y_validation +1;
    
    
    % Tried multinomial linear regression but did not put on poster
    
    MDLmnr{i} = mnrfit(x_train,y_train);

    
    
    % validation
    ypred = predict_ml(MDLmnr{i},x_validation); 
    yh = mnrval(MDLmnr{i},x_validation);
    
    y_validation = y_validation -1;
    
    yhat{i+90} = [ypred, yh, 1-yh, 1-yh, yh];
    y_val{i+90} = y_validation;
    MSE{i+90} = mean((y_validation - yh).^2);   
    

    
    RES{i+90} = confusionmat(y_validation,ypred);     
    Accuracy{i+90} = (RES{i+90}(1,1)+RES{i+90}(2,2))/(RES{i+90}(1,1)+RES{i+90}(2,2)+RES{i+90}(2,1)+RES{i+90}(1,2));  
    Precision{i+90} = RES{i+90}(1,1)/(RES{i+90}(1,1)+RES{i+90}(2,1));  
    Recall{i+90} = RES{i+90}(1,1)/(RES{i+90}(1,1)+RES{i+90}(1,2));  
    F1{i+90} = 2*(Recall{i+90} * Precision{i+90}) / (Recall{i+90} + Precision{i+90});   
 
end 

%%  Find the Best Models for each method
clc

A = cell2mat(Accuracy(1,1:10)'); %initial logistic regression
mean(A)

B = cell2mat(Accuracy(1,11:20)'); %disc fit
mean(B)

D = cell2mat(Accuracy(1,31:40)'); %LR after Lasso
mean(D)

I = cell2mat(Accuracy(1,81:90)'); %LR probit after Lasso
mean(I)

J = cell2mat(Accuracy(1,91:100)'); %MNR after Lasso
mean(J)

% choose LR after lasso because it is similar accuracy but with lower cost

%% Find Naive Bayes best model
clc

C = cell2mat(Accuracy(1,21:30)'); %initial naive bayes
mean(C)

E = cell2mat(Accuracy(1,41:50)'); %post lasso
mean(E)

FF = cell2mat(Accuracy(1,51:60)'); %kernel prior post lasso
mean(FF)

G = cell2mat(Accuracy(1,61:70)'); %prior only post lasso
mean(G)

H = cell2mat(Accuracy(1,71:80)'); %kernel mvmn lasso
mean(H)

% choose mnmn after lasso

%% Explore other parameter tuning using gradient descent


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);

    
    % use gradient descent and cost function
    % this matches the previous results
    % concept taken from https://www.youtube.com/watch?v=bQqtZyav6K8&t=592s
    
    [m , n] = size(x_train);
    initialTheta = zeros((n + 1), 1);
    %initialTheta = zeros((n ), 1);
    options = optimset('GradObj', 'on', 'MaxIter', 400);
    Theta = fminunc(@(t)computedCost(t, x_train, y_train), initialTheta, options);
    %Theta = fminunc(@(t)costfunctionreg(t, x_train, y_train, 1), initialTheta, options);
    
    predictions{i} = predict_ml(Theta, x_validation);
    Cost_1{i} = confusionmat(y_validation,predictions{i});
    Cost_Accuracy{i} = (Cost_1{i}(1,1)+Cost_1{i}(2,2))/(Cost_1{i}(1,1)+Cost_1{i}(2,2)+Cost_1{i}(2,1)+Cost_1{i}(1,2));  

    


end 


%% Add lambda to cost function 


for i = 1:numFolds
    idx = training(cv,i);
    train = trainData(idx,[4,14,18:26,32]);
    idx = test(cv,i);
    validation = trainData(idx,[1,4,14,18:26,32]);
    
    m_train = length(train);
    m_validation = length(validation);
    
    y_train = trainData(:,1);
    x_train = trainData(:,[4,14,18:26,32]);
    
    y_validation = validation(:,1);
    x_validation = validation(:,2:end);

    
    % cost function with gradient descent but with lambda regularization
    % added to the function
    % help with adding lambda using https://gist.github.com/rlopezcardenas/8195223
    
    [m , n] = size(x_train);
    %initialTheta = zeros((n + 1), 1);
    initialTheta = zeros((n ), 1);
    options = optimset('GradObj', 'on', 'MaxIter', 400);
    %Theta = fminunc(@(t)computedCost(t, x_train, y_train), initialTheta, options);
    Theta = fminunc(@(t)costfunctionreg(t, x_train, y_train, 1), initialTheta, options);
    
    
    predictions{i+10} = predict_ml2(Theta, x_validation);
    Cost_1{i+10} = confusionmat(y_validation,predictions{i+10});
    Cost_Accuracy{i+10} = (Cost_1{i+10}(1,1)+Cost_1{i+10}(2,2))/(Cost_1{i+10}(1,1)+Cost_1{i+10}(2,2)+Cost_1{i+10}(2,1)+Cost_1{i+10}(1,2));  


end

    % manually adjusted lambda to view how it impact results


%% Retrain models on full training set and evaluate with hold out test set



link = @(mu) log(mu ./ (1-mu));
derlink = @(mu) 1 ./ (mu .* (1-mu));
invlink = @(resp) 1 ./ (1 + exp(-resp));
F = {link, derlink, invlink};


train = trainData([4,14,18:26,32]);
    
y_train = trainData(:,1);
x_train = trainData(:,[4,14,18:26,32]);

    
% Logistic Regression
    
MDLglm_Best = glmfit(x_train,y_train,'binomial','link',F);
    
% Naive Bayes
    
MDLnb_Best =  fitcnb(x_train,y_train, 'DistributionNames', {'mvmn', 'kernel', 'mvmn', 'mvmn',...
    'mvmn', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel', 'kernel'});    
    


%% Evaluate Results

y_test = testData(:,1);
x_test = testData(:,[4,14,18:26,32]);


% find success values and create confusion matrix

yhat_LR = glmval(MDLglm_Best,x_test,F);
ypred_LR = predict_ml(MDLglm_Best,x_test); 
CM_LR = confusionmat(y_test,ypred_LR);   
Accuracy_LR = (CM_LR(1,1) + CM_LR(2,2)) / ...
    (CM_LR(1,1) + CM_LR(2,1) + CM_LR(1,2) + CM_LR(2,2));   

[~, yhat_NB, ~] = predict(MDLnb_Best,x_test);
ypred_NB = predict(MDLnb_Best,x_test); 
CM_NB = confusionmat(y_test,ypred_NB);     
Accuracy_NB = (CM_NB(1,1) + CM_NB(2,2)) / ...
    (CM_NB(1,1) + CM_NB(2,1) + CM_NB(1,2) + CM_NB(2,2));   



%% ROC of Best Models

% create ROC with AUC identified

[X,Y,T,AUC] = perfcurve(y_test, yhat_LR, classLabels(2,1));
[X1,Y1,T1,AUC1] = perfcurve(y_test, yhat_NB(:,2), classLabels(2,1));

figure(18)
plot(X,Y)
hold on
plot(X1,Y1)
legend('Logistic Regression  AUC=0.8935','Naive Bayes             AUC=0.8747','Location','Best')
xlabel('False positive rate') 
ylabel('True positive rate')
title('ROC Curves for Logistic Regression and Naive Bayes Classification')
hold off

%% Plot Confusion Matrix

%plotconfusion(y_test,ypred_L);

figure(19)
confusionchart(CM_LR, {'hit', 'out'}, 'RowSummary','row-normalized','ColumnSummary','column-normalized')
title('Logistic Regression Confusion Chart')
figure(20)
confusionchart(CM_NB, {'hit', 'out'}, 'RowSummary','row-normalized','ColumnSummary','column-normalized')
title('Naive Bayes Confusion Chart')

%% Plot Misclassification Errors

rng('default') % for reproducibility
cv = cvpartition(length(normData),'Holdout',.20);
idx = cv.test;

hit_out = categorical(completeData.hit_out);
x_loc = completeData.x_loc; 
y_loc = completeData.y_loc; 

hit_out = hit_out(idx);
x_loc = x_loc(idx);
y_loc = y_loc(idx);



figure(21)
hold on
scatter(x_loc(ypred_LR == y_test & y_test == 1),y_loc(ypred_LR == y_test & y_test == 1),10, 'b', 'Marker', '.')
scatter(x_loc(ypred_LR ~= y_test & y_test == 1),y_loc(ypred_LR ~= y_test & y_test == 1),10, 'r', 'Marker', 'x')
legend('True Outs','Mislabeled as Hits')
title('Logistic Regression Accuracy of Outs')
hold off

figure(22)
hold on
scatter(x_loc(ypred_LR == y_test & y_test == 0),y_loc(ypred_LR == y_test & y_test == 0),10, 'b', 'Marker', '.')
scatter(x_loc(ypred_LR ~= y_test & y_test == 0),y_loc(ypred_LR ~= y_test & y_test == 0),10, 'r', 'Marker', 'x')
legend('True Hits', 'Mislabeled as Outs')
title('Logistic Regression Accuracy of Hits')
hold off

figure(23)
hold on
scatter(x_loc(ypred_NB == y_test & y_test == 1),y_loc(ypred_NB == y_test & y_test == 1),10, 'b', 'Marker', '.')
scatter(x_loc(ypred_NB ~= y_test & y_test == 1),y_loc(ypred_NB ~= y_test & y_test == 1),10, 'r', 'Marker', 'x')
legend('True Outs','Mislabeled as Hits')
title('Naive Bayes Accuracy of Outs')
hold off

figure(24)
hold on
scatter(x_loc(ypred_NB == y_test & y_test == 0),y_loc(ypred_NB == y_test & y_test == 0),10, 'b', 'Marker', '.')
scatter(x_loc(ypred_NB ~= y_test & y_test == 0),y_loc(ypred_NB ~= y_test & y_test == 0),10, 'r', 'Marker', 'x')
legend('True Hits','Mislabeled as Outs')
title('Naive Bayes Accuracy of Hits')
hold off


%% Histogram of distribution of probabilities for NB and LR

figure(1)
hist(yhat_LR)
title('Probabilities for Logistic Regression')

figure(2)
hist(yhat_NB(:,2))
title('Probability Distribution for Naive Bayes')



