<template>
  <div class="card-body">
    <table class="table table-bordered table-hover responsive-table">
      <thead>
        <tr>
          <th>Categorie name</th>
          <th>Departement</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <each-item
          :socketio="socketio"
          :cat="cat"
          :iscat="true"
          v-for="(cat) in localCats_$"
          :key="cat.id"
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
  props: ["socketio", "cats"],
  components: { EachItem },
  data: function() {
    return {
      itemchanged: undefined,
      localCats: []
    };
  },
  created: function() {
    this.localItems = this.cats;
  },
  mounted: function() {
    this.$nextTick(() => {
      this.initSocket(this.socketio);
      console.log(this);
    });
  },
  computed: {
    localCats_$() {
      this.localCats = this.cats;
      return this.localCats;
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