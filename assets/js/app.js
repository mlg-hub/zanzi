import Vue from 'vue';
window.Vue = Vue;
import MainApp from './mainApp.vue';
// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.scss";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket";
window.adminchannel = socket.channel("admin:zanzi");
adminchannel
    .join()
    .receive("ok", resp => {
        console.log("The user joined with success", resp);
    })
    .receive("error", reason => {
        console.log("unable to join admin", reason);
    });
document.addEventListener("DOMContentLoaded", function () {
    let el = document.querySelector("#vuearea");
    let data = document.querySelector("#allitems");
    window.el = el;
    window.socketlink = socket;

    if (el != null) {
        const app = new Vue({
            el: el,
            template: "<MainApp :items='items':socket='socket' :cats='cats' :depts='depts'/>",
            components: {
                MainApp
            },
            created: function () {
                console.log(typeof data.dataset.items, JSON.parse(data.dataset.items));
            },
            data: function () {
                return {
                    items: JSON.parse(data.dataset.items),
                    depts: JSON.parse(data.dataset.depts),
                    cats: JSON.parse(data.dataset.cats),
                    socket: socketlink,
                };
            }
        });
    }
});