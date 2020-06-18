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
        <each-cat
          :socketio="socketio"
          :cat="cat"
          :iscat="true"
          v-for="(cat) in localCats_$"
          :key="cat.id"
          @updating="saveChange"
          :catchanged="catchanged"
          :depts="depts"
        ></each-cat>
      </tbody>
    </table>
  </div>
</template>
<script>
import EachCat from "./Eachcat";
export default {
  props: ["socketio", "cats", "depts"],
  components: { EachCat },
  data: function() {
    return {
      catchanged: undefined,
      localCats: []
    };
  },
  created: function() {
    this.localcats = this.cats;
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
      adminchannel.on("updated_cat", resp => {
        this.updateNewcat(resp.updated_cat);
      });
    },
    updateNewcat(cat) {
      const index = this.cats.findIndex(i => i.id == cat.id);
      console.log("this is index", index);
      this.cats[index] = cat;
      console.log("new cat", cat, this.cats[index]);
      this.localcats = [];
      this.localcats = this.cats;
      setTimeout(() => {
        const modal = document.querySelector(`#exampleModal${cat.id}`);
        modal.classList.remove("show");
        modal.style.display = "none";
        document.querySelector("body").classList.remove("modal-open");
        document.querySelector(".modal-backdrop").remove();
      }, 50);
    },
    saveChange(command) {
      // console.log("easy", command);
      adminchannel.push("update_cat", { body: command });
    }
  }
};
</script>