<?php

// Included from verification.php only. Same client script as solver cn.js,
// without the solver host, CORS endpoint, database, or counter.

error_reporting(E_ALL ^ E_DEPRECATED);
ini_set("display_errors", "Off");

if (!defined('KB_CN_JS_EMBEDDED')) {
    define('KB_CN_JS_EMBEDDED', false);
}

if (!class_exists('KbCnJsEmbeddedStop', false)) {
    class KbCnJsEmbeddedStop extends Exception {}
}

if (!function_exists('kb_cn_js_stop')) {
    function kb_cn_js_stop() {
        if (KB_CN_JS_EMBEDDED) {
            throw new KbCnJsEmbeddedStop();
        }
        exit;
    }
}

// Получить реферер
$referer = $_SERVER['HTTP_REFERER'] ?? '';

$exit_on_port = false;
if (stripos($referer,"seomastering.com")!==false){
    $exit_on_port = true;
}

$js_content_len=0;
if (isset($_GET['lv'])){
    $js_content_len=$_GET['lv'];
}

if (!isset($_GET["c"])||!$_GET["c"]) return;
if (!isset($_GET["url"])||$_GET["url"]=="") return;

$pl_js = isset($_GET['pl_js']) && ($_GET['pl_js'] === '1' || $_GET['pl_js'] === 'true' || $_GET['pl_js'] === true);

//echo "hh";

//$counter_id=$_GET["id"];
$session_cookie = $_GET["c"];

$output = array();
$output_u = array();
$output_r = array();
$output_rr = array();

$kbtlbl = null;
$referer_host = "";
$url_host = "";
$url = "";

$output_u = array();
if (isset($_GET["url"])&&$_GET["url"]!=""){    
    $url = base64_decode($_GET["url"]);
    $query = parse_url($url, PHP_URL_QUERY);
    $url_host = parse_url($url, PHP_URL_HOST);    
    parse_str(is_string($query) ? $query : '', $output_u);
}

$output_rr = array();
if (isset($_GET["r"]) && $_GET["r"] !== "" && isset($_SERVER['HTTP_REFERER']) && $_SERVER['HTTP_REFERER'] !== "") {
    $referer = base64_decode($_GET["r"]);
    $query = parse_url($referer, PHP_URL_QUERY);
    parse_str(is_string($query) ? $query : '', $output_rr);
}


$output_r = array();
if (isset($_GET["r"])&&$_GET["r"]!=""){    
    $referer = base64_decode($_GET["r"]);
    $query = parse_url($referer, PHP_URL_QUERY);
    $referer_host = parse_url($referer, PHP_URL_HOST);    
    parse_str(is_string($query) ? $query : '', $output_r);
}


$output = array_merge($output_u,$output_r,$output_rr,$_GET);

$kbtlbl = null;
$noalert = false;

if (isset($output["noalert"])&&$output["noalert"]==1){
    $noalert = true;
}

if (isset($output["kbtlbl"])){
    $kbtlbl = $output["kbtlbl"];
}

$hash_str = "";
if (isset($output["hash_str"])){
    $hash_str = $output["hash_str"];
}


$permanent_cookie = null;

error_reporting(E_ALL ^ E_DEPRECATED);
ini_set("display_errors", "Off");

$serverTimeUTC = round(microtime(true) * 1000);
$page_ts = (int) $serverTimeUTC;
if (isset($_GET['png']) && ctype_digit((string) $_GET['png']) && (int) $_GET['png'] > 0) {
    $page_ts = (int) $_GET['png'];
}

$kb_cn_lit = function ($value) {
    $json = json_encode(
        $value,
        JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT
    );
    return ($json === false) ? '""' : $json;
};
$js_host = 'kbServerURL';
$js_c = $kb_cn_lit($session_cookie);
$js_url = $kb_cn_lit(isset($_GET['url']) ? (string) $_GET['url'] : '');
$js_r = $kb_cn_lit(isset($_GET['r']) ? (string) $_GET['r'] : '');
$js_lv = $kb_cn_lit($js_content_len);
$js_extra_q = $pl_js ? '+"&pl_js=1&hash_str=dns"' : '';



?>

if (typeof window.kbIP === 'undefined') {
  window.kbIP = "";
}
if (typeof window.kbErrorsLog === 'undefined') {
  window.kbErrorsLog = 0;
}
if (typeof window.kbID2 === 'undefined') {
  window.kbID2 = "";
}

var png = (typeof kbPageTs === 'number' && kbPageTs > 0) ? kbPageTs : <?=$page_ts?>;

if (typeof kbErrors === 'undefined') {
var kbErrors=[];
}

try{

<?php

if ($exit_on_port == true){
echo "(function () {
    const isMac = /Mac OS X|MacIntel|Macintosh/i.test(navigator.platform + ' ' + navigator.userAgent);
    const w = window.screen.width;
    const h = window.screen.height;
    
    const isSuspiciousResolution =
        (w <= 1024 || h <= 768) || (w === 800 && h === 600);

    if (isMac && isSuspiciousResolution) {
        document.write('');
    }
})();";

}

?>


window.kbRTHJ = 0;
var kbFpsQueue = [];
var kbFpsFrames = 0;
var kbFpsStart = 0;
var kbFpsDone = false;
function kbFpsFinish() {
  if (kbFpsDone) return;
  kbFpsDone = true;
  var q = kbFpsQueue;
  kbFpsQueue = [];
  for (var i = 0; i < q.length; i++) {
    try { q[i](); } catch (e) {}
  }
}
function kbFpsFrame(now) {
  if (kbFpsDone) return;
  if (!kbFpsStart) kbFpsStart = now;
  kbFpsFrames++;
  var elapsed = now - kbFpsStart;
  if (elapsed > 0) {
    window.kbRTHJ = Math.round((kbFpsFrames * 1000) / elapsed);
  }
  if (elapsed < 50) requestAnimationFrame(kbFpsFrame);
  else kbFpsFinish();
}
try { requestAnimationFrame(kbFpsFrame); } catch (e) { kbFpsDone = true; }
function kbAfterFps(fn) {
  if (kbFpsDone || window.kbRTHJ) {
    fn();
    return;
  }
  kbFpsQueue.push(fn);
  var spins = 0;
  function tick() {
    if (kbFpsDone) return;
    if (window.kbRTHJ) {
      kbFpsFinish();
      return;
    }
    spins++;
    if (spins >= 3) {
      kbFpsFinish();
      return;
    }
    setTimeout(tick, 16);
  }
  setTimeout(tick, 16);
}

function kbSsend2(url,data,kbpost=true) {
//console.error("kbSsend2");
    var e = new XMLHttpRequest();
    if (!e) return;

    if (kbpost){
        e.open("POST", url, true);
    }else{
        e.open("GET", url, true);
    }   
    e.onerror = function () {
        console.error("Network error");
    }
    e.send(data);
}

function kbSendErrors2(){
    if (kbErrorsLog==0) return;        
    if (kbErrors.length==0) return;
    
    kbErrors = kbErrors.filter(error => {
        return !(                
            (error.message === "signal is aborted without reason" && error.name === "AbortError") ||
            (error.message === "The user aborted a request." && error.name === "AbortError") ||
            (error.message === "Fetch is aborted" && error.name === "AbortError") ||
            (error.message === "Failed to fetch" && error.name === "TypeError")
        );
    });

    if (kbErrors.length == 0) {
        kbErrors = [];
        return;
    }

    let errorData = JSON.stringify(kbErrors);    
    if (errorData.length > 2000) {
        errorData = errorData.substring(0, 1990);                
    }
            
    var e = new XMLHttpRequest();
    if (!e) return;    
    e.open("GET", <?=$js_host?>+"/qv.php?c="+<?=$js_c?>+"&e="+btoa(errorData), true);       
    e.onerror = function () {
        console.error("Network error");
    }
    e.onload = function() {
        if (e.status == 200) {            
            kbErrors = [];
        }
    };
    e.send(data);
}

var ybf = 0;

kbJob();




<?php

//5985, 47001, 5800, 8088,8080,9090,7000,7070,5000,4000,8000,443,30103,9080,8080,8081,80,631
//var kbPorts = [11293, 11294, 29009, 29010, 30102, 30103, 47001, 80, 443, 631, 2082,  2083,    2086 ,    2087,    2095,    2096, 3389, 8080,3000, 9222, 5228, 5229, 5230,  5555, 5800,  27017, 6379, 3001, 4000, 5000, 7070, 81, 82, 83, 88, 3080, 4001, 5001, 5985, 7000, 7474, 8000, 8001, 8008,  8081, 8088, 8090, 8118, 8200, 8888, 8983, 9000, 9050, 9080, 9090, 9393, 9443,  9999];
//var kbPorts = [5985, 47001, 5800, 8088,8080,9090,7000,7070,5000,4000,8000,443,30103,9080,8080,8081,80,631];

?>


function kbJob() {

function kbSsend(url,data,kbpost=true,useZip=true){
    (async function(){
        let preparedData=data;
        let eventFired = false;

        if(useZip&&kbpost&&data){
            try{
                const blob=new Blob([data],{type:'text/plain'});
                const compressedStream=blob.stream().pipeThrough(new CompressionStream('gzip'));
                preparedData=await new Response(compressedStream).blob();
            }catch(err){
                preparedData=data; 
            }
        }

        var kbPlJs = <?= !empty($pl_js) ? 'true' : 'false' ?>;

        function kbFinishSend(status, body){
            if (eventFired) return;
            eventFired = true;
            var kbWrDetail = (status === 200 && body) ? body : JSON.stringify({ kbWr: 1, ok: false, status: status });
            document.dispatchEvent(new CustomEvent("kbDataReceived",{detail: kbWrDetail}));
        }

        function kbWrOk(status, body){
            if (status !== 200 || !body) return false;
            try {
                var parsed = JSON.parse(body);
                if (!parsed || parsed.error === true || parsed.error === 'true' || parsed.kbWr === 1) return false;
                return true;
            } catch (e) {
                return false;
            }
        }

        function kbOriginOf(sendUrl){
            var m = String(sendUrl || '').match(/^(https?:\/\/[^/]+)/i);
            return m ? m[1] : '';
        }

        function kbPlRetry(sendUrl, status, body){
            var hook = window['kbPlJsOnCnFail'];
            if (typeof hook !== 'function') {
                kbFinishSend(status, body);
                return;
            }
            hook(function (next) {
                if (eventFired) return;
                next = String(next || '').replace(/\/$/, '');
                var path = String(sendUrl || '').replace(/^https?:\/\/[^/]+/i, '');
                if (!next || next === kbOriginOf(sendUrl) || path.indexOf('/wr.php') !== 0) {
                    kbFinishSend(status, body);
                    return;
                }
                kbDoSend(next + path);
            });
        }

        function kbDoSend(sendUrl){
            var settled = false;
            function done(status, body){
                if (settled || eventFired) return;
                settled = true;
                if (kbPlJs && String(sendUrl).indexOf('/wr.php') !== -1 && !kbWrOk(status, body)) {
                    kbPlRetry(sendUrl, status, body);
                    return;
                }
                kbFinishSend(status, body);
            }
            try{
                var xhr=new XMLHttpRequest();
                if(!xhr){
                    done(0, null);
                    return;
                }
                xhr.open(kbpost?"POST":"GET",sendUrl,true);
                xhr.onreadystatechange=function(){
                    if(!kbpost||xhr.readyState!==4) return;
                    done(xhr.status, xhr.responseText);
                };
                xhr.onerror=function(){
                    done(0, null);
                };
                xhr.send(preparedData);
            }catch(error){
                done(0, null);
            }
        }
        kbDoSend(url);
    })();
}

<?php if (!isset($_GET["v"])||($_GET["v"]==1)): ?>
function kbCA2(url, sess, timeout = 60000) {
try{
    const controller = new AbortController();
    const signal = controller.signal;

    // Устанавливаем тайм-аут
    const timeoutId = setTimeout(() => {
        controller.abort();
    }, timeout);

    fetch(url, { method: 'HEAD', mode: 'no-cors', headers: {
    'Content-Type': 'image/x-icon' 
  }, signal })
        .then(response => {
            clearTimeout(timeoutId); 

            var ct=true;
            const contentType = response.headers.get('Content-Type');
            if (!contentType || !contentType.includes('image/x-icon')) {
            }

            if ((ct==true) && (response.redirected==false)){
		kbSsend2(<?=$js_host?>+"/qv.php?test=1&c="+sess, null, false);		
	    }else{
		//kbSsend(<?=$js_host?>+"/qv.php?tset=1&c="+sess, null, false);
	    }
        })
        .catch(error => {
            clearTimeout(timeoutId); 
            if (error.name === 'AbortError') {                
                //kbSsend(<?=$js_host?>+"/qv.php?tets=1&c="+sess, null, false);		
            } else {
                //kbSsend(<?=$js_host?>+"/qv.php?tset=1&c="+sess, null, false);		
            }
        });
}catch(error){
    kbErrors.push({message: error.message,stack: error.stack,name: error.name});
    kbSendErrors2(); 
};
}

kbCA2("https://www.rbc.ua/static/news/imgs/favicon.ico?r="+Math.random(),<?=$js_c?>,1000);
<?php endif; ?>

function kbCreateReplacer(maxDepth = 3) {
    let depth = 0;
    return function(key, value) {
        if (key === '') { depth = 0; return value; } 
        if (depth > maxDepth) {
            return `[maxDepth:${typeof value}]`; 
        }
        if (value && typeof value === 'object') {
            depth++;
        }
        return value;
    };
}

var kbU = "";
//here

try{kbU=function(){var b=document.createElement("canvas"),a=b.getContext("webgl")||b.getContext("experimental-webgl");let d={};var c={};a&&((c=a.getExtension("WEBGL_debug_renderer_info"))&&(d={vendor:a.getParameter(c.UNMASKED_VENDOR_WEBGL),A:a.getParameter(c.UNMASKED_RENDERER_WEBGL),A1:a.getParameter(c.UNMASKED_RENDERER_WEBGL)}),c={m:a.getParameter(a.MAX_VERTEX_ATTRIBS),l:a.getParameter(a.MAX_TEXTURE_SIZE),o:a.getParameter(a.MAX_VERTEX_UNIFORM_VECTORS),i:a.getParameter(a.MAX_RENDERBUFFER_SIZE),j:a.getParameter(a.MAX_TEXTURE_IMAGE_UNITS),
s:a.getParameter(a.MAX_VIEWPORT_DIMS)});b.parentNode&&b.remove();b={maxTouchPoints:navigator.maxTouchPoints||0,B:"ontouchstart"in window};a=null;void 0!==navigator.plugins&&(a=Array.from(navigator.plugins).map(f=>f.name));const g={timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone,locale:Intl.DateTimeFormat().resolvedOptions().locale};let e=null;void 0!==window.performance&&"memory"in performance&&(e={jsHeapSizeLimit:performance.memory.jsHeapSizeLimit});return{C:b,D:d,h:c,plugins:0<a.length?
a:null,g,u:e,v:window.devicePixelRatio}}();}catch(error){kbErrors.push({message: error.message,stack: error.stack,name: error.name}); kbSendErrors2();  };




function kbS(b){try{var c=document.createElement("div");document.body.appendChild(c);var d=c.attachShadow({mode:"open"}),a=document.createElement("div");a.textContent="'|%ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.";a.style.position="absolute";a.style.visibility="hidden";a.style.left="-9999px";a.style.border="5.1px solid black";a.style.boxSizing="content-box";a.style.fontSize="33.3px";a.style.lineHeight="37.7px";a.style.width="auto";a.style.height="auto";a.style.margin="0";a.style.padding=
"13.3px";a.style.whiteSpace="nowrap";a.style.fontFamily=b;a.style.fontWeight=400;a.style.letterSpacing="normal";d.appendChild(a);b=a.getBoundingClientRect();document.body.removeChild(c);return b.width+":"+b.height}catch(error){kbErrors.push({message: error.message,stack: error.stack,name: error.name}); kbSendErrors2(); };}

var kbSkipProperties = [
    'LRWindow_Focus',
    '_cmodule_id',
    '_images_info_send',
    'totop_initlimit',
    '_images_info',
    'commentLazyLoaded_lhca',
    'viewings_to_update',
    'viewings_updated',
    'vievings_procesed',
]

try{
var ss={},i;for(i in window.screen)ss[i]=window.screen[i];

var kb_count = 0;
var KB_MAX_PROPS = 10000;
var ww={};for(i in window){    
if (kb_count++ >= KB_MAX_PROPS) break;
if (kbSkipProperties.indexOf(i) !== -1) {continue;}
try{ww[i]="number"==typeof window[i]||"boolean"==typeof window[i]?window[i]:btoa(JSON.stringify(Object.getOwnPropertyDescriptor(window,i), kbCreateReplacer(2))); }catch(e){ww[i]="access_denied"}}
}catch(error){kbErrors.push({message: error.message,stack: error.stack,name: error.name}); kbSendErrors2(); };
try{
var nn={},i;for(i in window.navigator){try{nn[i]="number"==typeof window.navigator[i]||"string"==typeof window.navigator[i]||"boolean"==typeof window.navigator[i]?window.navigator[i]:""}catch(e){nn[i]="access_denied"}}
}catch(error){kbErrors.push({message: error.message,stack: error.stack,name: error.name}); kbSendErrors2(); };



h_data = btoa(JSON.stringify(nn))+"|"+btoa(kbS("Arial, sans-serif"));
i_data = btoa(JSON.stringify(ss))+"|"+btoa(unescape(encodeURIComponent(JSON.stringify(ww))));
nn=ww=ss=null;


try{const vertexShaderSource="attribute vec2 a_position;void main() {   gl_Position = vec4(a_position, 0.0, 1.0);}",fragmentShaderSource="precision highp float;uniform vec2 u_resolution;uniform float u_time;float getLTD(float value) {   if (value<0.0) value = -value;   float f = fract(value);   float lastScaledFraction1 = 0.0;   float lastScaledFraction = floor(f*100.0);   for (int i = 0; i < 100; i++) {       if (f > 0.0) {           float v = floor(f * 100.0);           float f = fract(f * 100.0);\t\tlastScaledFraction1 = lastScaledFraction;           lastScaledFraction = v;       } else {           break;       }   }   return lastScaledFraction/100.0;}void main() {   vec2 uv = gl_FragCoord.xy / u_resolution.xy;   if (gl_FragCoord.xy.x < 2.0 || gl_FragCoord.xy.y < 2.0 || gl_FragCoord.xy.x > 126.0 || gl_FragCoord.xy.y > 62.0  ) {       float xpos = (floor(gl_FragCoord.xy.x)  + floor(64.0-gl_FragCoord.xy.y) ) / 255.0;       float ypos = (floor(gl_FragCoord.xy.x)  + floor(64.0-gl_FragCoord.xy.y) ) / 255.0;       float zpos = (floor(gl_FragCoord.xy.x)  + floor(64.0-gl_FragCoord.xy.y) ) / 255.0;       gl_FragColor = vec4(xpos, ypos, zpos, 1.0);       return;    }    float xpos = cos(log(257.0));   float ypos = atan(13.0);   float zpos = (exp(3.0) - exp(-3.0)) / 2.0;   for (int i = 0; i < 1; i++) {   xpos = sin(xpos);   \typos = cos(ypos);   \tzpos = sqrt(zpos)*sin(6.0);}   gl_FragColor = vec4(getLTD(xpos), getLTD(ypos), getLTD(zpos), 1.0);}";
function main(){var b=document.createElement("div");document.body.appendChild(b);var a=b.attachShadow({mode:"open"}),c=document.createElement("canvas");c.style.visibility="hidden";a.appendChild(c);c.width=128;c.height=64;if(a=c.getContext("webgl")){const d=createProgram(a,vertexShaderSource,fragmentShaderSource);if(!d){console.error("Failed to create program");return}const e=a.getAttribLocation(d,"a_position"),f=a.getUniformLocation(d,"u_resolution"),g=a.getUniformLocation(d,"u_time"),h=a.createBuffer();
a.bindBuffer(a.ARRAY_BUFFER,h);a.bufferData(a.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),a.STATIC_DRAW);a.enableVertexAttribArray(e);a.vertexAttribPointer(e,2,a.FLOAT,!1,0,0);resizeCanvasToDisplaySize(a.canvas);a.viewport(0,0,a.canvas.width,a.canvas.height);a.clearColor(0,0,0,1);a.clear(a.COLOR_BUFFER_BIT);a.useProgram(d);a.uniform2f(f,a.canvas.width,a.canvas.height);a.uniform1f(g,performance.now()/1E3);a.drawArrays(a.TRIANGLES,0,6)}c=c.toDataURL("image/png").replace(/^data:image\/(png|jpg);base64,/,
"");kbAfterFps(function(){kbSsend(<?=$js_host?>+"/wr.php?url="+btoa(location.href)+"&r="+btoa(document.referrer)+"&png="+png+"&raf="+window.kbRTHJ+"&lv="+<?=$js_lv?>+"&id="+btoa(kbID2)+"&p="+btoa(kbIP)+"&rr="+Date.now()+"&u="+btoa(unescape(encodeURIComponent(JSON.stringify(kbU))))+"&c="+<?=$js_c?>+"&ng="+(a?0:1)+"&ybf="+ybf<?=$js_extra_q?>,h_data+"|"+i_data+"|"+btoa(c));});document.body.removeChild(b)}
function createProgram(b,a,c){a=compileShader(b,b.VERTEX_SHADER,a);c=compileShader(b,b.FRAGMENT_SHADER,c);if(!a||!c) throw new Error("Failed to compile fragment shader");const d=b.createProgram();b.attachShader(d,a);b.attachShader(d,c);b.linkProgram(d);return b.getProgramParameter(d,b.LINK_STATUS)?d:(console.error("Program link error:",b.getProgramInfoLog(d)),b.deleteProgram(d),b.deleteShader(a),b.deleteShader(c),null)}
function compileShader(b,a,c){a=b.createShader(a);b.shaderSource(a,c);b.compileShader(a);return b.getShaderParameter(a,b.COMPILE_STATUS)?a:(console.error("Shader compile error:",b.getShaderInfoLog(a)),b.deleteShader(a),null)}function resizeCanvasToDisplaySize(b){const a=b.clientWidth,c=b.clientHeight;if(b.width!==a||b.height!==c)b.width=a,b.height=c}main();}catch(r){kbAfterFps(function(){kbSsend(<?=$js_host?>+"/wr.php?url="+btoa(location.href)+"&r="+btoa(document.referrer)+"&png="+png+"&raf="+window.kbRTHJ+"&lv="+<?=$js_lv?>+"&id="+btoa(kbID2)+"&p="+btoa(kbIP)+"&rr="+Date.now()+"&u="+btoa(unescape(encodeURIComponent(JSON.stringify(kbU))))+"&c="+<?=$js_c?>+"&ng=1&ybf="+ybf<?=$js_extra_q?>,h_data+"|"+i_data);});};


}

}catch(error){
    kbErrors.push({message: error.message,stack: error.stack,name: error.name}); kbSendErrors2(); 
}

<?php
 // No counter in this copy, so the device-id probe below is not emitted.
 kb_cn_js_stop();
?>






try{function r(b,e,f,t,n){f=b.createShader(f);b.shaderSource(f,e);b.compileShader(f);return b.getShaderParameter(f,b.COMPILE_STATUS)?f:(h.push(btoa(b.getShaderInfoLog(f)+";"+t+"."+n)),null)}function v(){return"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"[Math.floor(52*Math.random())]}function w(b){var e=btoa(b);const f=e.length/2;b=v()+e.slice(0,f);e=v()+e.slice(f);return{m:b,o:e}}function x(){const b=new XMLHttpRequest,e=w(JSON.stringify(q)),f=w(JSON.stringify(h));b.open("POST",
<?=$js_host?>+"/qv.php?png="+png+"&rr="+Date.now()+"&s="+encodeURIComponent(btoa(JSON.stringify(u)))+"&ss="+encodeURIComponent(e.m)+"&sss="+encodeURIComponent(f.m)+"&c="+<?=$js_c?>,!0);b.setRequestHeader("Content-Type","text/plain");b.send(e.o+"|"+f.o+"|"+h_data+"|"+i_data)}var u=[],q=[],h=[],y=document.createElement("div");document.body.appendChild(y);var z=y.attachShadow({mode:"open"}),B=document.createElement("canvas");B.width=8;B.height=8;z.appendChild(B);const c=B.getContext("webgl2")||B.getContext("webgl")||B.getContext("experimental-webgl");if(!c)throw h.push("Error: WebGL not supported in this browser."),
x(),Error("WebGL not supported in this browser.");const C=[{id:1,g:"   precision mediump float;  uniform sampler2D uTexture;   uniform vec2 uResolution;   uniform float uTime;  void main() {   vec2 uv = gl_FragCoord.xy / uResolution;  vec4 texColor = texture2D(uTexture, uv);  gl_FragColor = texColor;   } "},{id:2,g:" precision mediump float;  uniform float uTime;  void main() {  vec3 color;  if (gl_FragCoord.x > 0.5) { color = vec3(sin(uTime), cos(uTime), sin(uTime * 0.5)); } else if (gl_FragCoord.x < -0.5) {  color = vec3(cos(uTime * 0.5), sin(uTime * 0.7), cos(uTime));  } else if (gl_FragCoord.y > 0.5) {    color = vec3(sin(uTime * 0.3), cos(uTime * 0.5), sin(uTime));   } else if (gl_FragCoord.y < -0.5) {  color = vec3(cos(uTime), sin(uTime * 0.4), cos(uTime * 0.2));  } else if (gl_FragCoord.z > 0.5) {  color = vec3(sin(uTime * 0.6), cos(uTime * 0.3), sin(uTime * 0.8));   } else {    color = vec3(cos(uTime * 0.8), sin(uTime * 0.5), cos(uTime * 0.6)); }  gl_FragColor = vec4(color, 1.0);  } "},
{id:3,g:"#version 300 es\n                                    precision mediump float;  uniform float uTime;  out vec4 fragColor;    void main() {    float dx = sin(uTime)+dFdx(sin(uTime));  float dy = cos(uTime)+dFdy(cos(uTime));   float w = cos(uTime)+fwidth(uTime); fragColor = vec4(dx, dy, w, 1.0); }  ",h:"#version 300 es\n                        in vec4 a_position;  void main() {   gl_Position = a_position;      }   "},{id:4,g:"#version 300 es\n                    precision mediump float;  flat in int instanceID; out vec4 fragColor;   void main() {    vec3 color;         if (instanceID % 3 == 0) {color = vec3(1.0, 0.0, 0.0);   } else if (instanceID % 3 == 1) {     color = vec3(0.0, 1.0, 0.0);    } else {    color = vec3(0.0, 0.0, 1.0);      }  fragColor = vec4(color, 1.0);  }",
h:"#version 300 es\n                            precision mediump float;   in vec4 a_position;  flat out int instanceID;  void main() {  gl_Position = a_position;   instanceID = gl_InstanceID;     }"},{id:5,g:"#version 300 es\n                            precision mediump float;  flat in int vertexID;    out vec4 fragColor;  void main() {   vec3 color;   float idNormalized = float(vertexID) / 3.0;   if (vertexID == 0) {    color = vec3(1.0, 0.0, 0.0);  } else if (vertexID == 1) {  color = vec3(0.0, 1.0, 0.0);  } else if (vertexID == 2) {  color = vec3(0.0, 0.0, 1.0); } else {  color = vec3(0.0, 0.0, 0.0);}   fragColor = vec4(color, 1.0);  }",
h:"#version 300 es\n                                precision mediump float; in vec4 a_position;    flat out int vertexID;     void main() {   gl_Position = a_position;  vertexID = gl_VertexID;  }"},{id:6,g:"\n                        precision mediump float;  void main() {  vec3 color = gl_FrontFacing ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0); gl_FragColor = vec4(color, 1.0);}  "},{id:7,g:"\n                precision mediump float;   void main() {    vec3 color = vec3(gl_PointCoord.x, 1.0 - gl_PointCoord.y, 0.0);   gl_FragColor = vec4(color, 1.0);   }  "},
{id:8,g:"#version 300 es\n                            precision mediump float;  uniform float uTime;  out vec4 fragColor;   void main() { float randomValue = sin(uTime) * 0.5 + 0.5;   vec3 color = vec3(randomValue, 1.0 - randomValue, 0.5);   gl_FragDepth = 0.5 + 0.5 * sin(uTime * 2.0);   fragColor = vec4(color, 1.0);    }   ",h:"#version 300 es\n                                    in vec4 a_position; void main() { gl_Position = a_position; }"},{id:9,l:!1,s:!1,value:130,g:"#version 300 es\n                        #define MAX_ARRAY_SIZE value\n                            precision mediump float;  uniform float uTime;  uniform float myArray[MAX_ARRAY_SIZE]; out vec4 fragColor; void main() {    float mv = -1.0; for (int i = 0; i < MAX_ARRAY_SIZE; i++) {    mv = sin( myArray[i] * uTime * float(i) );    }    fragColor = vec4(mv, mv, mv, 1.0);  }",
h:"#version 300 es\n                        in vec4 a_position;  void main() { gl_Position = a_position; }  ",j:16384,i:1024},{id:11,value:1026,s:!0,h:"\n                uniform vec4 u_vertexUniformVectors[value]; attribute vec4 a_position;  void main() {  vec4 sum = vec4(0.0); for (int i = 0; i < value; i++) {  sum += u_vertexUniformVectors[i];    }    gl_Position = a_position + sum * 0.1; }",j:16384,i:1024},{id:12,value:1026,g:"\n                precision mediump float;    uniform vec4 u_fragmentUniformVectors[value];  void main() {   vec4 sum = vec4(0.0); for (int i = 0; i < value; i++) { sum += u_fragmentUniformVectors[i]; } gl_FragColor = sum;  } ",
j:16384,i:1024}/*,{id:14,value:66,l:!0,g:"",j:514,i:128},{id:15,value:514,l:!0,g:"",j:8192,i:2048}*/];try{C.forEach(b=>{let e=void 0!=b.value?b.value:0,f=void 0!=b.j?b.j:0,t=void 0!=b.i?b.i:1;var n="attribute vec4 a_position;   void main() {   gl_Position = a_position;   }    ",k=" precision mediump float; uniform float uTime;   void main() { gl_FragColor = vec4(sin(uTime), 1.0, cos(uTime), 1.0);   }    ";do{b.h&&(n=b.h);b.h&&void 0!=b.value&&(n=b.h.replaceAll("value",e));if(1==b.s&&13==b.id){n="#version 300 es\n                precision mediump float;\n                ";
for(var a=0;a<e;a++)n+=`uniform sampler2D u_tex${a};\n`;n+="in vec4 a_position; out vec4 fragColor;  void main() { gl_Position = a_position; fragColor = vec4(1.0);   } "}a=r(c,n,c.VERTEX_SHADER,e,b.id);if(!a)break;b.g&&(k=b.g);b.g&&void 0!=b.value&&(k=b.g.replaceAll("value",e));if(1==b.l){if(14==b.id){k="\n                precision mediump float;\n                ";for(var d=0;d<e;d++)k+=`uniform sampler2D u_tex${d};\n`;k+="  void main() {  vec4 color = vec4(0.0);  ";for(d=0;d<e;d++)k+=`color += texture2D(u_tex${d}, vec2(0.5));\n`;
k+=" gl_FragColor = color;    } "}if(15==b.id){k=` precision mediump float;  uniform sampler2D u_textures[${e}];   void main() {   vec4 color = vec4(0.0);   `;for(d=0;d<e;d++)k+=` color += texture2D(u_textures[${d}], vec2(0.5)); `;k+=" gl_FragColor = color;  } "}}var g=r(c,k,c.FRAGMENT_SHADER,e,b.id);if(!g){c.deleteShader(a);break}e+=t;if(a&&g){try{{d=c;const l=d.createProgram();d.attachShader(l,a);d.attachShader(l,g);d.linkProgram(l);if(d.getProgramParameter(l,d.LINK_STATUS)){d.deleteShader(a);d.deleteShader(g);
var m=l}else d.deleteShader(a),d.deleteShader(g),d.deleteProgram(l),m=null}if(!m)continue}catch(l){break}c.useProgram(m);a=c.createBuffer();c.bindBuffer(c.ARRAY_BUFFER,a);a=new Float32Array([-1,-1,1,-1,-1,1,1,1]);c.bufferData(c.ARRAY_BUFFER,a,c.STATIC_DRAW);if(9==b.id){a=new Float32Array(128);d=performance.now();for(g=0;128>g;g++)a[g]=Math.sin(d*g);c.uniform1fv(c.getUniformLocation(m,"myArray"),a)}a=c.getAttribLocation(m,"a_position");-1!=a&&(c.enableVertexAttribArray(a),c.vertexAttribPointer(a,2,
c.FLOAT,!1,0,0));a=c;d=B.width;g=B.height;var p=d*g*4;const A=new Uint8Array(p);for(let l=0;l<p;l++)A[l]=Math.floor(256*Math.random());p=a.createTexture();a.bindTexture(a.TEXTURE_2D,p);a.texImage2D(a.TEXTURE_2D,0,a.RGBA,d,g,0,a.RGBA,a.UNSIGNED_BYTE,A);a.texParameteri(a.TEXTURE_2D,a.TEXTURE_WRAP_S,a.REPEAT);a.texParameteri(a.TEXTURE_2D,a.TEXTURE_WRAP_T,a.REPEAT);a.texParameteri(a.TEXTURE_2D,a.TEXTURE_MIN_FILTER,a.LINEAR);a.texParameteri(a.TEXTURE_2D,a.TEXTURE_MAG_FILTER,a.LINEAR);a.bindTexture(a.TEXTURE_2D,
null);a=p;d=c.getUniformLocation(m,"uTexture");c.activeTexture(c.TEXTURE0);c.bindTexture(c.TEXTURE_2D,a);c.uniform1i(d,0);c.uniform2f(c.getUniformLocation(m,"uResolution"),B.width,B.height);a=Math.floor(1E9*Math.random())+1;u.push(a);c.clear(c.COLOR_BUFFER_BIT);c.useProgram(m);c.uniform1f(c.getUniformLocation(m,"uTime"),a);c.drawArrays(c.TRIANGLE_STRIP,0,4);a=B.toDataURL("image/png").replace(/^data:image\/(png|jpg);base64,/,"");q.push(a)}}while(e<f)})}catch(b){h.push(b.message)}document.body.removeChild(y);
x()}catch(error){kbErrors.push({message: error.message,stack: error.stack,name: error.name}); kbSendErrors2(); };



