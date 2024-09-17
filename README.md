# Airport Shooting Evacuation Model

## Project Overview

This project simulates an emergency evacuation at Buffalo Airport in the event of a gunman scenario. The model is developed using **Agent-Based Modeling (ABM)** and **GIS** data to replicate the movement of agents (passengers, gunmen, and security personnel) in different areas of the airport. 

The primary goal of the simulation is to study how people behave during an active shooting and how security personnel respond to neutralize the threat, as well as the evacuation process towards safety exits and elevators.

## Features

- **GIS Data Integration**: Uses `MapAir.shp` to represent different areas of the airport and `PofE.shp` to represent safety exits and elevators.
- **Agent Types**: The model includes passengers, security personnel, and gunmen, each having specific behaviors and interaction rules.
- **Realistic Constraints**: Evacuation processes are constrained by the capacity of safety exits and elevators, adding realism to the simulation.
- **Emergency Response**: Security personnel respond by converging towards the gunman, while passengers attempt to evacuate as quickly as possible.
- **Spatial Awareness**: Agents are aware of area types and avoid certain zones like the `FA` (infrastructure area) and `CA` (commercial area) during evacuation.

## GIS Data

- `MapAir.shp`: Defines different areas in the airport, such as:
  - `MG`: Lobby (where passengers enter and are generated)
  - `SC`: Security Check (where gunmen appear)
  - `FA`: Infrastructure Area (ATM, etc.)
  - `CA`: Commercial Area (shops, etc.)
  - `waiting`: Waiting Area
- `PofE.shp`: Defines safety exits and elevators:
  - Exits: Used by passengers and security personnel during evacuation.
  - Elevators: Have a capacity of 8 people and operate every minute.

## Agent Behaviors

- **Passengers**: Randomly generated in waiting areas, lobby, commercial area, and security check. During an active shooter event, they attempt to reach the nearest safety exit or elevator.
- **Security Personnel**: Generated in the security check area and the waiting area. Personnel in the security check area converge towards the gunman once a shooting is detected.
- **Gunmen**: Appear randomly in the security check area and can shoot at nearby passengers and security personnel within a range of 10 meters.

## Evacuation Rules

- **Safety Exits**: Can only accommodate two people at a time.
- **Elevators**: Have a capacity of 8 people and operate every minute, providing an alternative evacuation route.

## Installation and Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/airport-evacuation-model.git
   cd airport-evacuation-model
2. Ensure you have the following dependencies installed:
- Python 3.x
- NetLogo (for running the ABM simulation)
- ArcGIS Pro (for handling GIS data)
3. Run the simulation in NetLogo using the airport_shooting_model.nlogo file.
4.Modify the parameters for agent populations and airport layout as needed through the sliders in the NetLogo interface.

## How to Use
1. Modify Parameters: You can adjust the number of passengers, security personnel, and gunmen through the sliders.
2. Run Simulation: Click Setup to initialize the model and Go to start the simulation.
3. Monitor Results: Observe how the agents behave and analyze the evacuation routes, time, and response of security personnel.

## Contributing
Contributions are welcome! Feel free to open an issue or submit a pull request if you have any suggestions or improvements.

## Contact
For any inquiries or questions, please contact Zhongyu Zhou at [zzhou47@buffalo.edu].
