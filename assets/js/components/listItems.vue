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
          v-for="(item, index) in localItems_$"
          :key="index"
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
      localItems: this.items
    };
  },
  created: function() {
    console.log("in lists", this.socketio);
  },
  mounted: function() {
    this.$nextTick(() => {
      this.initSocket(this.socketio);
    });
  },
  computed: {
    localItems_$() {
      return this.localItems;
    }
  },
  methods: {
    initSocket(socket) {
      let adminchannel = socket.channel("admin:zanzi");
      this.adminchannel = adminchannel;
      this.adminchannel
        .join()
        .receive("ok", resp => {
          console.log("The user joined with success", resp);
        })
        .receive("error", reason => {
          console.log("unable to join admin", reason);
        });
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
      this.localItems = [...this.items];
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
      this.adminchannel.push("update_item", { body: command });
    }
  }
};
</script>