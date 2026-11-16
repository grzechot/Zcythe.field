# zhop_islands_test.py - z-hop test print: 60 x 60 x 1 mm plate + 6 x 6 cylinders D6 x H4 mm (10 mm grid).
# Every layer of the cylinders = 36 travels with retraction and z-hop (about 2400 z-hops at 0.12 mm layers).
# Run with FreeCAD 1.0:  freecadcmd zhop_islands_test.py  -> zhop_islands_test.step / .stl
import os
import FreeCAD as App
import Part
import Mesh

D = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
BASE, T, N, PITCH, DIA, H = 60.0, 1.0, 6, 10.0, 6.0, 4.0

shape = Part.makeBox(BASE, BASE, T)
cyl = [Part.makeCylinder(DIA / 2, H, App.Vector(PITCH / 2 + i * PITCH, PITCH / 2 + j * PITCH, T)) for i in range(N) for j in range(N)]
shape = shape.fuse(cyl).removeSplitter()
out = os.path.join(D, "zhop_islands_test")
shape.exportStep(out + ".step")
Mesh.Mesh(shape.tessellate(0.01)).write(out + ".stl")
print("volume %.1f mm3 -> %s.step / .stl" % (shape.Volume, out))
