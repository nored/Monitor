//= require jquery-3.3.1.min
//= require popper.min
//= require bootstrap.min
//= require knockout-3.5.0
//= require d3.v3.min

function Online(data) {
    this.online= ko.observable(data);
}

function Offline(data) {
    this.offline= ko.observable(data);
}

function Avgload(data) {
    this.avgload= ko.observable(data);
}

function Avgtemp(data) {
    this.avgtemp= ko.observable(data);
}
  
var color = d3.scale.category20b();

var width = 600,
    height = 300,
    margin = 50,
    thickness = 100,
    radius = Math.min(width, 2 * height) / 2,
    angleRange = 0.5 * Math.PI;

var pie = d3.layout.pie()
    .sort(null)
    .startAngle(angleRange * -1)
    .endAngle(angleRange);

var arc = d3.svg.arc()
    .innerRadius(radius - margin - thickness)
    .outerRadius(radius - margin);

var svg1 = d3.select("#my_dataviz1").append("svg")
    .attr("width", width)
    .attr("height", height)
    .append("g")
    .attr("transform", "translate(" + width / 2 + "," + (height - margin / 2) + ")");

var path1 = svg1.selectAll("path")
    .data(pie([0, 2]))
    .enter().append("path")
    .attr("fill", function(d, i) {
    return color(i);
    })
    .attr("d", arc);

var load_percentage = Math.floor(0 *100 / 2)

svg1.append("text")
    .attr("dy", "-.3em")
    .attr("dx", "-0.95em")
    .attr("font-size", "90px")
    .attr("font-family", "sans-serif")
    .text(function(d) { return load_percentage + "%"; });
    
    
var svg2 = d3.select("#my_dataviz2").append("svg")
    .attr("width", width)
    .attr("height", height)
    .append("g")
    .attr("transform", "translate(" + width / 2 + "," + (height - margin / 2) + ")");

var path2 = svg2.selectAll("path")
    .data(pie([0, 70]))
    .enter().append("path")
    .attr("fill", function(d, i) {
    return color(i);
    })
    .attr("d", arc);

svg2.append("text")
    .attr("dy", "-.3em")
    .attr("dx", "-0.95em")
    .attr("font-size", "90px")
    .attr("font-family", "sans-serif")
    .text(function(d) { return Math.floor(0) + "°"; });


function updateChart1(avgload){
    var load_percentage = Math.floor(avgload *100 / 2)
    svg1.selectAll("path")
        .data(pie([avgload, 2]))
        .transition()
        .duration(1000)
        .attr("fill", function(d, i) {
        return color(i);
        })
        .attr("d", arc);
    svg1.selectAll("text")
        .transition()
        .duration(1000)
        .attr("dy", "-.3em")
        .attr("dx", "-0.95em")
        .attr("font-size", "90px")
        .attr("font-family", "sans-serif")
        .text(function(d) { return load_percentage + "%"; });
}

function updateChart2(avgtemp){
    svg2.selectAll("path")
        .data(pie([Math.floor(avgtemp), 70]))
        .transition()
        .duration(1000)
        .attr("fill", function(d, i) {
        return color(i);
        })
        .attr("d", arc);

    svg2.selectAll("text")
        .transition()
        .duration(1000)
        .attr("dy", "-.3em")
        .attr("dx", "-0.95em")
        .attr("font-size", "90px")
        .attr("font-family", "sans-serif")
        .text(function(d) { return Math.floor(avgtemp) + "°"; });
}

function MonitorViewModel() {
    var t = this;

    t.offline = ko.observableArray([]);
    t.online = ko.observableArray([]);
    t.avgload = ko.observable();
    t.avgtemp = ko.observable();
    
    t.update = function() {
   
    $.getJSON("/offline", function(raw) {
        var offline = $.map(raw, function(item) { return new Offline(item) });
        t.offline(offline);
    });

    $.getJSON("/online", function(raw) {
        var online = $.map(raw, function(item) { return new Online(item) });
        t.online(online);
    });

    $.getJSON("/allload", function(data) {
        t.avgload(data.load);
        updateChart1(data.load);
    });

    $.getJSON("/alltemp", function(data) {
        t.avgtemp(data.temp);
        updateChart2(data.temp);
    });

    };

}
var monitorViewModel = new MonitorViewModel();
window.setInterval(monitorViewModel.update,5000);
ko.applyBindings(monitorViewModel);


