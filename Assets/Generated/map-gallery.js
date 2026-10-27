/* Offline preview: uses the delivered raster assets, no dependencies or network. */
const $ = id => document.getElementById(id);
const before = $('before');
let fallbackTried = false;
const referenceNote = document.createElement('p');
before.after(referenceNote);
before.onerror = () => {
 if (!fallbackTried) {
  fallbackTried = true;
  referenceNote.textContent = 'Fallback: existing repository screenshot from docs/store/tests/. The requested app-jetzt-1.png and target style references were not supplied.';
  before.src = '../../../docs/store/tests/stil-' + (WEST ? 'wild-west' : 'toy-town') + '-karte.png';
 } else { before.hidden = true; before.style.display='none'; $('missing').hidden = false; }
};
before.style.display = 'none';
before.onload = () => { before.hidden = false; before.style.display = 'block'; $('missing').hidden = true; };
before.src = REFERENCE;
let previousURL;
$('upload').onchange = e => {
 const file = e.target.files[0]; if (!file) return;
 if (previousURL) URL.revokeObjectURL(previousURL);
 referenceNote.textContent = 'Locally selected comparison screenshot.';
 before.src = previousURL = URL.createObjectURL(file);
};
$('expand').onclick = () => document.querySelectorAll('details').forEach(d => d.open = true);
$('collapse').onclick = () => document.querySelectorAll('details').forEach(d => d.open = false);
$('alpha').onchange = e => document.body.classList.toggle('checker', e.target.checked);
const canvas = $('map'), ctx = canvas.getContext('2d'), images = new Map();
function sprite(name, x, y, w, h = w) {
 const im = images.get(name); if (im) ctx.drawImage(im, x-w/2, y-h/2, w,h);
}
function line(points, color, width, dash=[]) {
 ctx.beginPath(); points.forEach(([x,y],i) => i?ctx.lineTo(x,y):ctx.moveTo(x,y));
 ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.lineJoin='round';ctx.setLineDash(dash);ctx.stroke();ctx.setLineDash([]);
}
function pattern(name, fallback) { return images.has(name)?ctx.createPattern(images.get(name),'repeat'):fallback; }
function label(text,x,y,angle=0) {
 ctx.save();ctx.translate(x,y);ctx.rotate(angle);ctx.font=WEST?'italic 15px Georgia':'600 14px system-ui';ctx.textAlign='center';ctx.lineWidth=4;ctx.strokeStyle=WEST?'#E4C9A8':'#ffffff';ctx.strokeText(text,0,0);ctx.fillStyle=WEST?'#3A2D20':'#2B2B2B';ctx.fillText(text,0,0);ctx.restore();
}
function drawWest() {
 ctx.fillStyle='#E4C9A8';ctx.fillRect(0,0,720,550);
 ctx.fillStyle=pattern('paper-tile','#E4C9A8');ctx.fillRect(0,0,720,550);
 ctx.save();ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(180,0);ctx.bezierCurveTo(158,100,85,154,121,270);ctx.bezierCurveTo(145,370,67,450,0,550);ctx.closePath();ctx.fillStyle='#a8b4ac';ctx.fill();ctx.clip();ctx.fillStyle=pattern('water-edge','#a8b4ac');ctx.fillRect(0,0,190,550);ctx.restore();
 if($('decor').checked) {
  ctx.save();ctx.beginPath();ctx.ellipse(567,114,140,88,-.2,0,Math.PI*2);ctx.clip();ctx.fillStyle=pattern('hill-hatch','transparent');ctx.fillRect(400,10,320,220);ctx.restore();
  [[440,70],[485,68],[535,62],[587,82],[620,106],[453,112],[497,119],[547,117],[592,145],[660,147],[450,170],[500,169],[565,181],[627,192],[174,380],[197,421],[164,455],[220,468],[253,431]].forEach(([x,y],i)=>sprite('forest-stamp-'+(i%6+1),x,y,32));
  ctx.strokeStyle='#715b43';ctx.fillStyle='#cfb18d';ctx.lineWidth=1;
  [[243,119,30,20],[287,112,22,26],[348,126,34,20],[385,158,22,20],[261,224,29,23],[321,225,24,30],[397,252,35,23],[469,318,28,23],[528,335,34,25],[579,329,25,21],[578,439,37,22]].forEach(([x,y,w,h])=>{ctx.fillRect(x,y,w,h);ctx.strokeRect(x,y,w,h);line([[x,y+h*.6],[x+w*.5,y],[x+w,y+h*.6]],'#8a7053',.8);});
 }
 const roads=[[[177,550],[209,440],[257,348],[306,266],[350,190],[391,105],[425,0]],[[122,159],[234,177],[350,190],[465,219],[581,247],[720,264]],[[257,348],[387,371],[512,398],[720,419]],[[512,398],[542,321],[581,247]]];
 roads.forEach(p=>{line(p,'#68503a',10);line(p,'#eed9bb',7)});
 line([[207,440],[257,348],[306,266],[350,190],[465,219],[581,247]],'#a55b42',3.5,[7,5]);
 if($('labels').checked){label('Mill Road',260,166,.09);label('Frontier Avenue',426,369,.17);label('Cedar Trail',372,94,-1.13);label('Willow Creek',67,311,-1.25);}
 sprite('west-poi-coffee',276,218,36);sprite('west-poi-fuel',482,293,36);sprite('west-poi-hotel',610,370,36);
 sprite('waypoint-x',581,247,48);sprite('player-arrow',250,365,64);
}
function drawToy() {
 ctx.fillStyle='#3EB34A';ctx.fillRect(0,0,720,550);ctx.fillStyle=pattern('toy-grass','#3EB34A');ctx.fillRect(0,0,720,550);
 const roads=[[[0,270],[720,270]],[[205,550],[205,0]],[[510,550],[510,0]],[[205,440],[510,440]]];
 const roadPath=()=>{ctx.beginPath();roads.forEach(p=>{ctx.moveTo(...p[0]);p.slice(1).forEach(q=>ctx.lineTo(...q));});ctx.moveTo(568,270);ctx.arc(510,270,58,0,Math.PI*2);};
 for(const [width,color]of [[52,'#2B2B2B'],[46,'#F2C230'],[40,'#9A9A9A']]){roadPath();ctx.strokeStyle=color;ctx.lineWidth=width;ctx.stroke();}
 ctx.save();roadPath();ctx.strokeStyle=pattern('toy-asphalt','#9A9A9A');ctx.lineWidth=36;ctx.stroke();ctx.restore();
 roads.forEach(p=>line(p,'#FFFFFF',2,[12,12]));ctx.beginPath();ctx.arc(510,270,58,0,Math.PI*2);ctx.strokeStyle='#fff';ctx.lineWidth=2;ctx.setLineDash([10,10]);ctx.stroke();ctx.setLineDash([]);
 ctx.beginPath();ctx.arc(510,270,35,0,Math.PI*2);ctx.fillStyle='#3EB34A';ctx.fill();ctx.strokeStyle='#F2C230';ctx.lineWidth=3;ctx.stroke();sprite('toy-pond',510,270,62);
 if($('decor').checked){
  [['toy-house-1',89,98],['toy-house-2',300,96],['toy-house-3',394,96],['toy-house-4',80,385],['toy-house-5',301,355],['toy-house-6',400,355],['toy-shop',103,184],['toy-school',352,183],['toy-hospital',625,162],['toy-fire-station',623,369],['toy-police',622,467],['toy-apartment',350,508]].forEach(([n,x,y])=>sprite(n,x,y,64));
  [[146,58],[262,180],[425,180],[581,64],[667,70],[45,475],[134,478],[260,505],[453,509],[577,509]].forEach(([x,y],i)=>sprite('toy-tree-round-'+['small','medium','large'][i%3],x,y,[32,48,64][i%3]));
  sprite('toy-flower-bed',78,322,64,48);sprite('toy-bush-group',350,395,64,48);
 }
 if($('labels').checked){label('Maple Street',345,252);label('Park Avenue',187,365,-Math.PI/2);label('School Lane',355,430);}
 sprite('toy-poi-shop',140,199,48);sprite('toy-poi-hospital',660,197,48);sprite('toy-poi-food',425,134,48);
 sprite('toy-car-red',205,374,64);sprite('toy-flag',510,117,64);
}
function draw(){ctx.clearRect(0,0,720,550);WEST?drawWest():drawToy();}
Promise.all(ASSETS.map(a=>new Promise(resolve=>{const im=new Image();im.onload=()=>{images.set(a.name,im);resolve()};im.onerror=()=>resolve();im.src=a.files[0];}))).then(()=>{draw();const missing=ASSETS.filter(a=>!images.has(a.name));$('loadstatus').textContent=missing.length?`${missing.length} assets unavailable: ${missing.map(a=>a.name).join(', ')}`:'All delivered assets loaded.';});
$('labels').onchange=draw;$('decor').onchange=draw;
