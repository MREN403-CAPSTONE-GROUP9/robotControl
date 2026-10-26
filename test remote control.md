to test remote control:

run on remote 
```
ros2 topic pub -r 1 /msg std_msgs/msg/String data:\ 'Hello, ROSbot here'
```

run on controller 
```
ros2 topic echo /msg
```

both must be on the same LAN 

if controller is WSL try running in mirror mode 
https://learn.microsoft.com/en-us/windows/wsl/wsl-config#configuration-settings-for-wslconfig

> derived from https://husarion.com/tutorials/ros2-tutorials/6-robot-network/
