<template>
  <div>
    <header-component @filtering="filter($event)" @newitem="saveNewItem($event)" :cats="cats"></header-component>
    <list-cat :cats="filterItems_$" :socketio="socket"></list-cat>
  </div>
</template>

<script>
import HeaderComponent from "./components/header";
import ListCat from "./components/listcat";

export default {
  name: "CatMain",
  props: ["socket", "cats"],
  components: { HeaderComponent, ListCat },
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
        return this.cats;
      } else {
        console.log("full");
        const filter = this.cats.filter(i =>
          i.name.toLowerCase().match(this.query.toLowerCase())
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