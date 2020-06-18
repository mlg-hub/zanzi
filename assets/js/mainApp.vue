<template>
  <div>
    <header-component
      @filtering="filter($event)"
      @newitem="saveNewItem($event)"
      :depts="depts"
      :cats="cats"
    ></header-component>
    <list-items :items.sync="filterItems_$" :socketio="socket" :depts="depts"></list-items>
  </div>
</template>

<script>
import HeaderComponent from "./components/header";
import ListItems from "./components/listItems";

export default {
  name: "MainApp",
  props: ["items", "socket", "depts", "cats"],
  components: { HeaderComponent, ListItems },
  data() {
    return {
      query: ""
    };
  },
  created() {},
  mounted() {
    this.$nextTick(() => {
      this.initSocket(this.socket);
    });
  },
  computed: {
    filterItems_$() {
      if (this.query == "") {
        console.log("empty");
        return this.items;
      } else {
        console.log("full");
        const filter = this.items.filter(
          i =>
            i.name.toLowerCase().match(this.query.toLowerCase()) ||
            i.departement.name.toLowerCase().match(this.query.toLowerCase())
        );
        console.log(filter);
        return filter;
      }
    }
  },
  methods: {
    initSocket(socket) {
      // console.log("hey", socket);
      // adminchannel.on("updated_item", resp => {
      //   this.updateNewItem(resp.updated_item);
      // });
      adminchannel.on("insert_item", resp => {
        window.location.reload();
      });
    },
    saveNewItem(item) {
      console.log("hey is item", item);
      adminchannel.push("new_item", { body: item });
    },
    filter(query) {
      this.query = query;
    }
  }
};
</script>