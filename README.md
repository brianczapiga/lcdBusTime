I created this app after breaking my toes in a motorcycle accident.

This will drive a Matrix Orbital style display configured for 16 columns x 2 lines

This was specifically designed to work with the USB Serial LCD Display from AdaFruit.

I have not cleaned the code, and I expect that there are optimizations that can
be made in a bunch of places.

The display will change color for status:

Blue for loading data
Yellow for no data. (Invalid API key, or badly formed request.)
Red for no buses within local threshold for route1.
Green for buses within local threshold for route1.

The display only changes color for the first route. The second route information is displayed on the second line, but does not affect the color.

The code also does not fork, and this will run in the foreground by default. This is in the to do list along with fixing the logic for color coding.
