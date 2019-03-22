function Task(data) {
    this.description = ko.observable(data.description);
    this.complete = ko.observable(data.complete);
    this.created_at = ko.observable(data.created_at);
    this.updated_at = ko.observable(data.updated_at);
    this.id = ko.observable(data.id);
    this.isvisible = ko.observable(true);
}
 
function TaskViewModel() {
    var t = this;
    t.tasks = ko.observableArray([]);
    t.newTaskDesc = ko.observable();
    t.sortedBy = [];
    t.query = ko.observable('');
    t.MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
 
 
    $.getJSON("http://localhost:9393/tasks", function(raw) {
        var tasks = $.map(raw, function(item) { return new Task(item) });
        t.tasks(tasks);
    });
 
    t.incompleteTasks = ko.computed(function() {
        return ko.utils.arrayFilter(t.tasks(), function(task) { return (!task.complete() && task._method != "delete") });
    });
    t.completeTasks = ko.computed(function() {
        return ko.utils.arrayFilter(t.tasks(), function(task) { return (task.complete() && task._method != "delete") });
    });
 
    // Operations
    t.dateFormat = function(date){
        if (!date) { return "refresh to see server date"; }
        var d = new Date(date);
        return d.getHours() + ":" + d.getMinutes() + ", " + d.getDate() + " " + t.MONTHS[d.getMonth()] + ", " + d.getFullYear();
    }
    t.addTask = function() {
        var newtask = new Task({ description: this.newTaskDesc() });
        $.getJSON("/getdate", function(data){
            newtask.created_at(data.date);
            newtask.updated_at(data.date);
            t.tasks.push(newtask);
            t.saveTask(newtask);
            t.newTaskDesc("");
        })
    };
    t.search = function(task){
        ko.utils.arrayForEach(t.tasks(), function(task){
            if (task.description() && t.query() != ""){
                task.isvisible(task.description().toLowerCase().indexOf(t.query().toLowerCase()) >= 0);
            } else if (t.query() == "") {
                task.isvisible(true);
            } else {
                task.isvisible(false);
            }
        })
        return true;
    }
    t.sort = function(field){
        if (t.sortedBy.length && t.sortedBy[0] == field && t.sortedBy[1]==1){
                t.sortedBy[1]=0;
                t.tasks.sort(function(first,next){
                    if (!next[field].call()){ return 1; }
                    return (next[field].call() < first[field].call()) ? 1 : (next[field].call() == first[field].call()) ? 0 : -1;
                });
        } else {
            t.sortedBy[0] = field;
            t.sortedBy[1] = 1;
            t.tasks.sort(function(first,next){
                if (!first[field].call()){ return 1; }
                return (first[field].call() < next[field].call()) ? 1 : (first[field].call() == next[field].call()) ? 0 : -1;
            });
        }
    }
    t.markAsComplete = function(task) {
        if (task.complete() == true){
            task.complete(true);
        } else {
            task.complete(false);
        }
        task._method = "put";
        t.saveTask(task);
        return true;
    }
    t.destroyTask = function(task) {
        task._method = "delete";
        t.tasks.destroy(task);
        t.saveTask(task);
    };
    t.removeAllComplete = function() {
        ko.utils.arrayForEach(t.tasks(), function(task){
            if (task.complete()){
                t.destroyTask(task);
            }
        });
    }
    t.saveTask = function(task) {
        var t = ko.toJS(task);
        $.ajax({
             url: "http://localhost:9393/tasks",
             type: "POST",
             data: t
        }).done(function(data){
            task.id(data.task.id);
        });
    }
}
ko.applyBindings(new TaskViewModel());