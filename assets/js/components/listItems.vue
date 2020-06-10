<template>
  <div class="card-body">
    <table class="table table-bordered table-hover responsive-table">
      <thead>
        <tr>
          <th>Item name</th>
          <th>Departement</th>
          <th>Price</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <each-item
          :socketio="socketio"
          :item="item"
          v-for="(item) in localItems_$"
          :key="item.id"
          :depts="depts"
          @updating="saveChange"
          :itemchanged="itemchanged"
        ></each-item>
      </tbody>
    </table>
  </div>
</template>
<script>
import EachItem from "./EachItem";
export default {
  props: ["items", "socketio", "depts"],
  components: { EachItem },
  data: function() {
    return {
      itemchanged: undefined,
      localItems: []
    };
  },
  // updated: function() {
  //   this.$nextTick(function() {
  //     // Code that will run only after the
  //     // entire view has been re-rendered
  //     console.log("updated");
  //   });
  // },
  created: function() {
    this.localItems = this.items;
    this.items;
    console.log("in lists", this.socketio);
  },
  mounted: function() {
    this.$nextTick(() => {
      this.initSocket(this.socketio);
    });
  },
  computed: {
    localItems_$() {
      this.localItems = this.items;
      return this.localItems;
    }
  },
  methods: {
    initSocket(socket) {
      // console.log("hey", socket);
      adminchannel.on("updated_item", resp => {
        this.updateNewItem(resp.updated_item);
      });
    },
    updateNewItem(item) {
      const index = this.items.findIndex(i => i.id == item.id);
      console.log("this is index", index);
      this.items[index] = item;
      console.log("new item", item, this.items[index]);
      this.localItems = [];
      this.localItems = this.items;
      setTimeout(() => {
        const modal = document.querySelector(`#exampleModal${item.id}`);
        modal.classList.remove("show");
        modal.style.display = "none";
        document.querySelector("body").classList.remove("modal-open");
        document.querySelector(".modal-backdrop").remove();
      }, 50);
    },
    saveChange(command) {
      // console.log("easy", command);
      adminchannel.push("update_item", { body: command });
    }
  }
};
</script>