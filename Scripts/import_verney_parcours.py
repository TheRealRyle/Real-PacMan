"""Build a review-only parcours from a saved OSM XML extract.
Usage: python3 Scripts/import_verney_parcours.py boundary.osm map.osm
Never downloads tiles, adds imaginary paths, or declares a parcours field-verified.
"""
import sys, math, json, uuid
from pathlib import Path
import xml.etree.ElementTree as ET

NAMESPACE = uuid.UUID("84661ea4-edfc-43fc-90ee-667c3ca78f50")
def identifier(text): return str(uuid.uuid5(NAMESPACE, text)).upper()
def coordinate(node):
    return {"latitude": float(node.attrib["lat"]), "longitude": float(node.attrib["lon"])}
def distance(a, b):
    return math.hypot((a["latitude"]-b["latitude"])*111320,
                      (a["longitude"]-b["longitude"])*111320*math.cos(math.radians(a["latitude"])))
def main(boundary_file, map_file):
    boundary_root = ET.parse(boundary_file).getroot()
    nodes = {n.attrib["id"]: coordinate(n) for n in boundary_root.findall("node")}
    park = next(w for w in boundary_root.findall("way") if w.attrib["id"]=="37562187")
    boundary = [nodes[n.attrib["ref"]] for n in park.findall("nd")][:-1]
    def inside(p):
        x,y=p["longitude"],p["latitude"]
        result=False
        for a,b in zip(boundary,boundary[1:]+boundary[:1]):
            ax,ay=a["longitude"],a["latitude"]; bx,by=b["longitude"],b["latitude"]
            if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax: result=not result
        return result
    root=ET.parse(map_file).getroot()
    nodes.update({n.attrib["id"]:coordinate(n) for n in root.findall("node")})
    blocked={n.attrib["id"] for n in root.findall("node")
             if any(t.attrib["k"] in ("access","foot") and t.attrib["v"] in ("no","private","destination")
                    for t in n.findall("tag"))}
    paths=[]
    adjacent={}
    for way in root.findall("way"):
        tags={t.attrib["k"]:t.attrib["v"] for t in way.findall("tag")}
        if tags.get("highway") not in ("footway","pedestrian","path"): continue
        if tags.get("area")=="yes" or tags.get("footway") in ("crossing","sidewalk"): continue
        if any(tags.get(key) in ("no","private","destination") for key in ("access","foot")): continue
        refs=[n.attrib["ref"] for n in way.findall("nd")]
        for i,(a,b) in enumerate(zip(refs,refs[1:])):
            if a==b or a in blocked or b in blocked: continue
            midpoint={key:(nodes[a][key]+nodes[b][key])/2 for key in ("latitude","longitude")}
            if not all(inside(p) for p in (nodes[a],nodes[b],midpoint)): continue
            if distance(nodes[a],nodes[b])<.1: continue
            paths.append({"id":way.attrib["id"]+":"+str(i), "from":a, "to":b,
                          "coordinates":[nodes[a],nodes[b]],"osmWayID":way.attrib["id"]})
            adjacent.setdefault(a,set()).add(b); adjacent.setdefault(b,set()).add(a)
    # Keep one connected component. Disconnected mapped paths remain excluded, not joined artificially.
    unseen=set(adjacent); components=[]
    while unseen:
        group=set(); queue=[min(unseen)]
        while queue:
            node=queue.pop()
            if node in group: continue
            group.add(node); queue.extend(adjacent[node]-group)
        unseen-=group; components.append(group)
    component=max(components,key=len)
    paths=sorted([p for p in paths if p["from"] in component],key=lambda p:p["id"])
    # Southernmost mapped network node is a proposed start, not an approved park entrance.
    start=min(component,key=lambda n:(nodes[n]["latitude"],nodes[n]["longitude"]))
    pellets=[]
    for p in paths:
        a,b=p["coordinates"]
        count=max(1,math.ceil(distance(a,b)/25))
        for step in range(count+1):
            t=step/count
            point={key:round(a[key]+(b[key]-a[key])*t,7) for key in a}
            if all(distance(point,old["coordinate"])>=22 for old in pellets):
                pellets.append({"id":identifier("pellet:"+p["id"]+":"+str(step)),
                                "coordinate":point,"value":10})
    length=sum(distance(*p["coordinates"]) for p in paths)
    route={"id":"7DAB402C-797E-4B41-A47D-54D01D1CF361","name":"Parc du Verney",
           "version":1,"coordinates":paths[0]["coordinates"],"pellets":pellets,
           "mapStyleURL":"https://tiles.openfreemap.org/styles/liberty",
           "parcours":{
               "description":"Explore the mapped walking paths of Parc du Verney in Chambéry. Map-based prototype; access, proposed start and pellet spacing still need an on-foot review.",
               "boundary":boundary,"startJunctionID":start,
               "junctions":[{"id":n,"coordinate":nodes[n]} for n in sorted(component)],
               "paths":paths,"supportedModes":["explore"],"estimatedMinutes":max(5,math.ceil(length/60)),
               "fieldVerified":False,"sourceURL":"https://www.openstreetmap.org/way/37562187",
               "sourceDate":"2026-11-10"
           }}
    out=Path(__file__).resolve().parents[1]/"Real Pacman/ParcoursData/verney-draft.json"
    out.write_text(json.dumps(route,indent=2,ensure_ascii=False)+"\n")
    print(f"Verney draft: {len(component)} nodes, {len(paths)} segments, {len(pellets)} proposed pellets, {length:.0f} m of paths")
if __name__=="__main__": main(*sys.argv[1:])
