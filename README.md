# lcdBusTime

I created this app after breaking my toes in a motorcycle accident.

# Hardware
This will drive a Matrix Orbital style display configured for 16 columns x 2 lines

This was specifically designed to work with the USB Serial LCD Display from AdaFruit.

https://www.adafruit.com/products/784

# General
I have not cleaned the code, and I expect that there are optimizations that can
be made in a bunch of places.

The display will change color for status:

Blue for loading data
Yellow for no data. (Invalid API key, or badly formed request.)
Red for no buses within local threshold for route1.
Green for buses within local threshold for route1.

The display only changes color for the first route. The second route information is displayed on the second line, but does not affect the color.

# To Do
The code does not fork, and this will run in the foreground by default. The code will be changed to run as a daemon.
The logic for color status is poorly implemented, and parses the final output text. This will be rewritten.

# License
This code is free, please give attribution where possible.
