To install Gazebo Jetty:  
1. `cd robotEnv/`  
2. `sudo apt-get install ros-lyrical-ros-gz`
   
To run simulation:

1. `cd robotEnv/simulation/`

2. `ros2 launch ros_gz_sim gz_sim.launch.py gz_args:=generic_robot.sdf`

To control robot using arrow keys:

1. Click 3 dots at top right corner and select "Key Publisher".

2. Open a new terminal and navigate to robotEnv/

3. `gz topic -e -t /keyboard/keypress`

4. Go back to sim window, click play button at bottom left corner, and use arrow keys. Terminal will display numerical input from arrow keys and robot will move in sim.
