# Import the live recording from the camera communication library
from Camera_com import camera_live

# Import live recording from the minispect communication library
from MS_com import minispect_live

# Multiprocessing library for multiple, independent processes
import multiprocessing as mp
import asyncio

async def main():
    # Test out the minispect live funcitonality
    await minispect_live()




if(__name__ == '__main__'):
    asyncio.run(main())