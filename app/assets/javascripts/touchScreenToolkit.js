//include.js :
// this is the only file necessary to call in pages using the ToolKit in the
// current version

/*******************************************************************************
 *
 * Baobab Touchscreen Toolkit
 *
 * A library for transforming HTML pages into touch-friendly user interfaces.
 *
 * (c) 2011 Baobab Health Trust (http://www.baobabhealth.org)
 *
 * For license details, see the README.md file
 *
 ******************************************************************************/

// Check if calling file is an example or an external page
var path = window.location.href.match(/assets/i);

var fromIframe = window.location.href.match(/^data/i);

var ext = (path && !fromIframe ? "" : "assets/");
var timerout = 10;   // 150;
var calledMethod = null;
var numberOfTrials = 0;
    
function __$(id){
    return document.getElementById(id);
}

function include(file){
    /*
     * Disabled the iniitial overloading as it was causing issues as in most cases
     * 2 copies of the same file were being loaded and caused conflicts
     * */
    // Three links for the same file are also created to allow for usage of the calls in
    // pure HTML prototypes as well as RAILS application with 2 scenarios for pure
    // HTML prototypes in cases where sub-folders are used; a kind of overloading
    // due to javascript limitations as it can't check file existence
    // var script1 = document.createElement("script");
    // script1.setAttribute("language", "javascript");
    // script1.setAttribute("src", "../" + ext + "lib/javascripts/" + file + (!file.match(/\.js$/) ? ".js" : ""));
    // script1.setAttribute("type", "text/javascript");

    // document.getElementsByTagName("head")[0].appendChild(script1);

    var script2 = document.createElement("script");
    script2.setAttribute("language", "javascript");
    script2.setAttribute("src", "/assets/" + file + (!file.match(/\.js$/) ? ".js" : ""));
    script2.setAttribute("type", "text/javascript");

    document.getElementsByTagName("head")[0].appendChild(script2);

    // var script3 = document.createElement("script");
    // script3.setAttribute("language", "javascript");
    // script3.setAttribute("src", ext + "lib/javascripts/" + file + (!file.match(/\.js$/) ? ".js" : ""));
    // script3.setAttribute("type", "text/javascript");

    // document.getElementsByTagName("head")[0].appendChild(script3);

    var fileType = file.match(/multiTouch|dashboard|standard/i);

    if(fileType){
        fileType = fileType[0];

        switch(fileType){
            case "multiTouch":
                includeCss("multiTouch");
                includeCss("dashboard");
                break;
            case "dashboard":
                includeCss("graytabs");
                includeCss("dashboard");
                includeCss("touch-fancy");
                break;
            default:
                includeCss("form");
                includeCss("graytabs");
                includeCss("touch-fancy");
                includeCss("calendar");
                break;
        }
    }
}

// Three links for the same file are created to allow for usage of the method in
// pure HTML prototypes as well as RAILS application with 2 scenarios for pure
// HTML prototypes in cases where sub-folders are used; a kind of overloading
// due to javascript limitations as it can't check file existence
function includeCss(file){
    /*
     * Disabled the iniitial overloading as it was causing issues as in most cases
     * 2 copies of the same file were being loaded and caused conflicts
     * */
    if(file != undefined){
        /*
        var link1 = document.createElement("link");
        link1.setAttribute("rel", "stylesheet");
        link1.setAttribute("href", ext + "lib/stylesheets/" + file + (!file.match(/\.css$/) ? ".css" : ""));
        link1.setAttribute("type", "text/css");

        document.getElementsByTagName("head")[0].appendChild(link1);
        */
       
        var link2 = document.createElement("link");
        link2.setAttribute("rel", "stylesheet");
        link2.setAttribute("href", "/assets/" + file + (!file.match(/\.css$/) ? ".css" : ""));
        link2.setAttribute("type", "text/css");

        document.getElementsByTagName("head")[0].appendChild(link2);

    /*
        var link3 = document.createElement("link");
        link3.setAttribute("rel", "stylesheet");
        link3.setAttribute("href", "../" + ext + "lib/stylesheets/" + file + (!file.match(/\.css$/) ? ".css" : ""));
        link3.setAttribute("type", "text/css");
        
        //document.getElementsByTagName("head")[0].appendChild(link3);
         */
    }
}

function createLoadingMessage(){
    var msg = document.createElement("div");
    msg.id = "loadingProgressMessage";
    msg.style.zIndex = 1000;
    msg.style.color = "#00f";
    msg.style.backgroundColor = "#fff";
    msg.style.fontSize = "2em";
    msg.style.position = "absolute";
    msg.style.left = "0px";
    msg.style.top = "0px";
    msg.style.width = "100%";
    msg.style.height = "100%";
    msg.style.margin = "0px";
    msg.style.textAlign = "center";
    msg.style.verticalAlign = "middle";

    document.body.appendChild(msg);

    var progressAnimation = document.createElement("div");
    progressAnimation.id = "progressAnimation";
    progressAnimation.style.position = "absolute";
    progressAnimation.style.top = "calc(50% - 20px)";
    progressAnimation.style.left = "calc(50% - 150px)";
    progressAnimation.innerHTML = "Loading. Please Wait...";
    progressAnimation.style.fontStyle = "italic";

    msg.appendChild(progressAnimation);

    setTimeout("changeProgressMessage('progressAnimation')", timerout);
}

function changeProgressMessage(id){
    var obj = __$(id);

    if(numberOfTrials > 50){
        // alert("A Synchronisation Error Must have Occurred. Retrying!");
        
        setTimeout(calledMethod, timerout);
        
        numberOfTrials = 0;
    } else {
        numberOfTrials++;
    }

    if(obj){
        if(obj.innerHTML.trim() == "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading"))){
            obj.innerHTML = "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + "";
        } else if(obj.innerHTML.trim() == "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + ""){
            obj.innerHTML = "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + ".";
        } else if(obj.innerHTML.trim() == "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + "."){
            obj.innerHTML = "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + "..";
        } else if(obj.innerHTML.trim() == "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + ".."){
            obj.innerHTML = "" + (typeof(tstLocaleWords) != "undefined" ?
(tstLocaleWords["loading. please wait"] ? tstLocaleWords["loading. please wait"] : I18n.t("messages.loading")) : I18n.t("messages.loading")) + "...";
        }

        setTimeout("changeProgressMessage('" + id + "')", timerout);
    }
}

// Load progress message
createLoadingMessage();

// Check the kind of page we have and render accordingly
// Added half a minute sleep to allow the page to finish loading.
if((document.forms[0] != undefined ? (document.forms[0].getAttribute("extended") != null ?
    (document.forms[0].getAttribute("extended") == "true" ? true : false) : false) : false)){

    include("multiTouch");
    calledMethod = "initMultipleQuestions()";
    setTimeout("initMultipleQuestions()", timerout);

} else if(__$('home') != null || __$('dashboard') != null || __$('general_dashboard') != null){

    include("dashboard");
    calledMethod = "createPage()";
    setTimeout("createPage()", timerout);

} else {
    try {
        include("standard");
        include("calendar");
        //include("datepicker");
        calledMethod = "loadTouchscreenToolkit()";
        setTimeout("loadTouchscreenToolkit()", timerout);
    }catch(e){}
}

function log_action(activity)
{
    var log = "Pressed " + activity+ " at " + new Date().getTime();
    if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        xmlhttp=new XMLHttpRequest();
    }else{// code for IE6, IE5
        xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
    }
    xmlhttp.onreadystatechange=function() {
        if (xmlhttp.readyState==4 && xmlhttp.status==200) {

        }
    }
    xmlhttp.open("GET","/user/log_action?activity="+log ,true);
    xmlhttp.send();

}