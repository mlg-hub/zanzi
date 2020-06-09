<template>
  <div>
    <header-component :depts="depts" :cats="cats"></header-component>
    <list-items :items="items" :socketio="socket" :depts="depts"></list-items>
  </div>
</template>

<script>
import HeaderComponent from "./components/header";
import ListItems from "./components/listItems";

export default {
  name: "MainApp",
  props: ["items", "socket", "depts", "cats"],
  components: { HeaderComponent, ListItems },
  created() {
    // console.log("new vue created", this.socket);
  }
};
</script>