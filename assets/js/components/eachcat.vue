<template>
  <tr>
    <td>{{cat.name}}</td>
    <td>{{cat.departement.name}}</td>
    <td style="display:flex; justify-content: space-around">
      <span style="cursor: pointer" data-toggle="modal" :data-target="'#exampleModal' + cat.id">
        <i style="color: orange" class="fas fa-edit"></i>
      </span>
      <span style="cursor: pointer">
        <i style="color: orangered" class="fas fa-trash"></i>
      </span>
    </td>
    <div
      class="modal fade"
      :id="'exampleModal' + cat.id"
      tabindex="-1"
      role="dialog"
      aria-labelledby="exampleModalLabel"
      aria-hidden="true"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">Edit cat</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label class="label" for="name">cat name:</label>
              <input id="name" class="form-control" v-model="catUpdated.name" />
            </div>
            <div class="form-group">
              <label class="label" for="dpt">cat departement:</label>
              <select class="form-control" v-model="selectedDept">
                <option
                  :value="id"
                  v-for="{name, id} in depts"
                  :key="id"
                  :selected="cat.departement.name == name"
                >{{name}}</option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
            <button type="button" class="btn btn-primary" @click="updatecats()">Save changes</button>
          </div>
        </div>
      </div>
    </div>
  </tr>
</template>
<script>
export default {
  props: ["cat", "depts", "catchanged"],
  created: function() {},
  mounted: function() {},
  data: function() {
    return {
      adminchannel: undefined,
      selectedDept: undefined,
      catUpdated: {
        id: undefined,
        name: undefined
      }
    };
  },
  created: function() {
    console.log("my cat", this.cat);
    if (!!this.cat.departement.name) {
      console.log("heellooo!!", this.cat.departement);
      this.selectedDept = this.cat.departement.id;
      this.catUpdated.name = this.cat.name;
      this.catUpdated.id = this.cat.id;
    }
  },
  methods: {
    updatecats() {
      console.log("...updating");
      this.$emit("updating", {
        ...this.catUpdated,
        selectedDept: this.selectedDept
      });
    }
  }
};
</script>