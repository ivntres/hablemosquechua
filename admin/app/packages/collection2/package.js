Package.describe({
    summary: "Wraps Meteor.Collection to provide support for automatic validation of insert and update operations on the client and server, plus simple virtual field support."
});

Package.on_use(function(api) {
    api.use(['simple-schema', 'check'], ['client', 'server']);
    if (typeof api.imply !== "undefined") {
        api.imply('simple-schema', ['client', 'server']);
    }
    //api.use('smart-collections', ['client', 'server'], {weak: true}); //weak dependencies are broken; removing this until fixed (meteor/meteor#1358)
    api.use('underscore', ['client', 'server']);
    api.use('deps', ['client', 'server']);
    api.add_files(['collection2.js'], ['client', 'server']);
});