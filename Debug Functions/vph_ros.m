%system('roslaunch stageroscam IGVC2013_AutoNavBasic3.launch');
addpath('/home/administrator/ros/mplab-ros-pkg/matlab_bridge');
addpath('/home/administrator/ros/mplab-ros-pkg/matlab_bridge/VFHP/VPHSupport');

jmb_init();

% Change this to your 
MASTER_URI='http://localhost:11311';
NODE_NAME='vph';
node=jmb_init_node(NODE_NAME, MASTER_URI);

% Create a Subscriber
lidarSub=edu.ucsd.SubscriberAdapter(node,'/base_scan','sensor_msgs/LaserScan');
odomSub=edu.ucsd.SubscriberAdapter(node,'/base_pose_ground_truth','nav_msgs/Odometry');
twistPub=jmb_init_publisher(node,'/cmd_vel','geometry_msgs/Twist');
%mapSub=jmb_init_publisher(node,'/localmap1','sensor_msgs/LaserScan');%lanelines
%in the map 360 info is assumed.

% left lines have intensity 0, right lanes have intensity 1, unknown lanes have intensity of 0.5 

%flagsSub=jmb_init_publisher(node,'/localmap2','sensor_msgs/LaserScan');%flags
% red flags have intensity 0, blue flags have intensity 1

timeout=2;
logger=node.getLog();
vfhStop=false;

% [linear_velocity, angular_velocity, vfh_state] = ...
%     VPH2010Algorithm(map, goal_angle, goal_dist, ...
%                  antigoal_angle, antigoal_dist, ...
%                  Vmax, vfh_state);
% calculate target heading
goal.x=-18.71;
goal.y=5.95;
anti_goal.x=30;
anti_goal.y=-30;
Vmax = 2.5; % maximum vehicle speed m/s

global sensor_min_angle sensor_max_angle sensor_resolution;
global vfh_state;
while (~vfhStop)    
%for i=1:10
    twistMsg =[];
    twistMsg=org.ros.message.geometry_msgs.Twist();
    lasermsg=lidarSub.takeMessage(timeout);
    odommsg=odomSub.takeMessage(timeout);
    if((~isempty(odommsg)) && (~isempty(lasermsg)))
        curr.x = -1 * odommsg.pose.pose.position.y;
        curr.y = odommsg.pose.pose.position.x;
        x= odommsg.pose.pose.orientation.x;
        y= odommsg.pose.pose.orientation.y;
        z= odommsg.pose.pose.orientation.z;
        w= odommsg.pose.pose.orientation.w;
        [curr.theta, pitch, roll] = quat2angle([w x y z]);
%         curr.theta = (mod(curr.theta+pi, 2*pi )-pi)*180/pi;
%         curr.theta = curr.theta+90;
%         if curr.theta > 180
%             curr.theta = curr.theta - 360;
%         end
        curr.theta = (mod(curr.theta+pi, 2*pi )-pi);
        curr.theta = curr.theta+pi/2;
        if curr.theta > pi
            curr.theta = curr.theta - 2*pi;
        end
        
        
        
        phi=atan2(goal.y - curr.y,goal.x - curr.x);
        goal_heading = limitAngleRad(phi-curr.theta)*180/pi;
        goal_dist = sqrt((goal.y - curr.y)^2+(goal.x - curr.x)^2);
        
        % For simulation%
        anti_phi=atan2(curr.y-anti_goal.y, curr.x-anti_goal.x);
        anti_goal_heading = limitAngleRad(anti_phi-curr.theta)*180/pi;
        anti_goal_dist = sqrt((anti_goal.y - curr.y)^2+(anti_goal.x - curr.x)^2);
        
        
        if (goal_dist < .5)
            vfhStop =true;
            continue;
        end
        lidarMinAngle = lasermsg.angle_min;
        sensor_min_angle = round(lasermsg.angle_min *180/pi); 
        % There in the main cases of 270 deg lidar and 360 deg
        % virtual-lidar, the min and max angle are spilling over due to
        % accuracy in representing angles in radians.
        lidarMaxAngle = lasermsg.angle_max;
        sensor_max_angle = lasermsg.angle_max *180/pi;
%         % There in the main cases of 270 deg lidar and 360 deg
        % virtual-lidar, the min and max angle are spilling over due to
        % accuracy in representing angles in radians.        
        lidarResolution = lasermsg.angle_increment;
        sensor_resolution = round (100*lasermsg.angle_increment *180/pi)/100;
        
        lidarMaxRange = lasermsg.range_max;
        lidarMinRanges = lasermsg.range_min;
        lidarRanges = lasermsg.ranges;
        lidarRanges(lidarRanges == 0) = lidarMaxRange; 
        lidarRanges(lidarRanges >= lidarMaxRange) = 8;
        % set lidar reading of 0 'nothing'to the maximum lidar range 
        % in compliance with player/stage convention.
        lidarRanges(181:360)=min(lidarRanges(181:360),lidarRanges(1:180));
        lidarRanges(900:-1:720)=min(lidarRanges(1081:-1:901),lidarRanges(900:-1:720));
%         [linear_velocity, angular_velocity] = ...
%             VPH2010Algorithm(lidarRanges, goal_heading, goal_dist, ...
%                         anti_goal_heading ,anti_goal_dist, Vmax, vfh_state);
[linear_velocity, angular_velocity] = ...
            VPH2010Algorithm(lidarRanges, goal_heading, goal_dist, ...
                        180 ,100, Vmax, vfh_state);        
            %ROS_INFO(msg)
            %logger.info(['I heard - ' char(msg.data)]);
            %lidarMsg=msg;
            %display('msg received')
            
       angular_velocity_rad = angular_velocity *pi/180;
       twistMsg.linear.x = linear_velocity;
       twistMsg.angular.z = angular_velocity_rad;
       twistPub.publish(twistMsg);
 
       %fprintf('q0 %f q1 %f q2 %f q3 %f\n',x, y, z, w);
       %fprintf('yaw %f pitch %f roll %f\n',curr.theta, pitch, roll);
      % fprintf('x %f y %f theta %f\n',curr.x, curr.y, curr.theta*180/pi);
%        fprintf('absolute goale heading %f\n',phi*180/pi);
%        fprintf('curTheta %f Goal_Theta %f antGoal_theta %f GoalDist %f linVel %f angVel %f\n'...
%           ,curr.theta*180/pi,goal_heading,anti_goal_heading,goal_dist,linear_velocity,angular_velocity);
     %  pause(.2);
     end




end
%node.shutdown()
