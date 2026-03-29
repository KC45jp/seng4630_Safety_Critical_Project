from Speed_SensorDataCreator import write_scenarios as write_scenariosSpeed
from Distance_SensorDataCreator import write_scenarios as write_scenariosDistance
from LanePosition_SensorDataCreator import write_scenarios as write_scenariosLanePosition

def main():
    write_scenariosSpeed()
    write_scenariosDistance()
    write_scenariosLanePosition()
if __name__ == "__main__":
    main()